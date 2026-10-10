import os
from typing import Annotated
from uuid import uuid4

import jwt
from fastapi import Depends, FastAPI, File, HTTPException, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from app import storage
from app.file_safety import MAX_FILE_SIZE, scan_file
from app.template_analysis import analyse_template, extract_logo

app = FastAPI(title="ConsentLink Service")
bearer_scheme = HTTPBearer(auto_error=False)
API_VERSION = "0.1.0"


class FileScanResponse(BaseModel):
    safe: bool
    detected_type: str
    size_mb: float
    reasons: list[str]


class TemplateAnalyseRequest(BaseModel):
    storage_path: str


class LogoExtractRequest(BaseModel):
    storage_path: str
    page: int = Field(ge=1, le=60)
    crop: list[float] | None = Field(default=None, min_length=4, max_length=4)


class HeadingStyle(BaseModel):
    font: str | None
    size_pt: float | None
    bold: bool


class StyleSpec(BaseModel):
    font: str | None
    size_pt: float | None
    heading: HeadingStyle
    line_spacing: float | None
    margins_cm: list[float]
    header: str | None
    footer: str | None
    logo_path: str | None
    columns: list[str]


class LogoCandidateResponse(BaseModel):
    page: int
    bbox: list[float]
    confidence: float


class TemplateAnalyseResponse(StyleSpec):
    confidence: dict[str, float]
    logo_candidates: list[LogoCandidateResponse]


class LogoExtractResponse(BaseModel):
    png_path: str
    bbox: list[float]
    confidence: float


def require_supabase_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ],
) -> HTTPAuthorizationCredentials:
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail={"code": "unauthorized", "message": "A bearer token is required."},
            headers={"WWW-Authenticate": "Bearer"},
        )

    secret = os.getenv("SUPABASE_JWT_SECRET")
    if not secret:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "auth_not_configured",
                "message": "Supabase JWT verification is not configured.",
            },
        )

    issuer = os.getenv("SUPABASE_URL", "").rstrip("/")
    options = {"require": ["exp", "sub", "role"]}
    try:
        claims = jwt.decode(
            credentials.credentials,
            secret,
            algorithms=["HS256"],
            audience="authenticated",
            issuer=f"{issuer}/auth/v1" if issuer else None,
            options=options,
        )
    except jwt.InvalidTokenError as error:
        raise HTTPException(
            status_code=401,
            detail={"code": "unauthorized", "message": "The bearer token is invalid."},
            headers={"WWW-Authenticate": "Bearer"},
        ) from error

    if claims.get("role") != "authenticated":
        raise HTTPException(
            status_code=403,
            detail={"code": "forbidden", "message": "An authenticated user is required."},
        )
    return credentials


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/v1/health")
def service_health() -> dict[str, bool | str]:
    return {"ok": True, "version": API_VERSION}


@app.post(
    "/v1/files/scan",
    response_model=FileScanResponse,
    dependencies=[Depends(require_supabase_user)],
)
async def scan_uploaded_file(file: Annotated[UploadFile, File()]) -> FileScanResponse:
    content = await file.read(MAX_FILE_SIZE + 1)
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail={
                "code": "file_too_large",
                "message": "The file exceeds the 25 MB upload limit.",
                "field": "file",
            },
        )

    result = scan_file(file.filename or "", content)
    return FileScanResponse(
        safe=not result.reasons,
        detected_type=result.detected_type,
        size_mb=round(len(content) / (1024 * 1024), 3),
        reasons=result.reasons,
    )


@app.post("/v1/templates/analyse", response_model=TemplateAnalyseResponse)
async def analyse_template_endpoint(
    request: TemplateAnalyseRequest,
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(require_supabase_user)],
) -> TemplateAnalyseResponse:
    stored_object, content = await storage.download_storage_object(
        request.storage_path, credentials.credentials
    )
    analysis = analyse_template(stored_object.name, content)
    return TemplateAnalyseResponse(
        **analysis.style_spec,
        confidence=analysis.confidence,
        logo_candidates=[
            LogoCandidateResponse(
                page=candidate.page,
                bbox=candidate.bbox,
                confidence=candidate.confidence,
            )
            for candidate in analysis.logo_candidates
        ],
    )


@app.post("/v1/logos/extract", response_model=LogoExtractResponse)
async def extract_logo_endpoint(
    request: LogoExtractRequest,
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(require_supabase_user)],
) -> LogoExtractResponse:
    stored_object, content = await storage.download_storage_object(
        request.storage_path, credentials.credentials
    )
    logo = extract_logo(stored_object.name, content, request.page, request.crop)
    logo_path = await storage.upload_storage_object(
        stored_object,
        f"logos/{uuid4().hex}.png",
        logo.png,
        credentials.credentials,
    )
    return LogoExtractResponse(
        png_path=logo_path,
        bbox=logo.bbox,
        confidence=logo.confidence,
    )


@app.exception_handler(HTTPException)
async def http_error_response(request: Request, error: HTTPException) -> JSONResponse:
    if isinstance(error.detail, dict) and "code" in error.detail:
        body = error.detail
    else:
        body = {"code": "http_error", "message": str(error.detail)}
    return JSONResponse(
        status_code=error.status_code,
        content=body,
        headers=error.headers,
    )


@app.exception_handler(RequestValidationError)
async def validation_error_response(
    request: Request, error: RequestValidationError
) -> JSONResponse:
    field = error.errors()[0]["loc"][-1] if error.errors() else None
    body: dict[str, str] = {
        "code": "invalid_request",
        "message": "The request is missing or contains an invalid field.",
    }
    if field is not None:
        body["field"] = str(field)
    return JSONResponse(status_code=422, content=body)
