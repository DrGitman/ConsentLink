from datetime import datetime, timedelta, timezone
from io import BytesIO
from typing import Any
from zipfile import ZipFile

import fitz
import httpx
import jwt
import pytest
from docx import Document
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app import storage
from app.main import app
from app.template_analysis import analyse_template, extract_logo

client = TestClient(app)
JWT_SECRET = "template-test-secret-with-at-least-thirty-two-bytes"
SUPABASE_URL = "https://storage.test"
SUPABASE_ANON_KEY = "test-anon-key"


def auth_headers() -> dict[str, str]:
    now = datetime.now(timezone.utc)
    token = jwt.encode(
        {
            "sub": "template-test-user",
            "role": "authenticated",
            "aud": "authenticated",
            "iss": f"{SUPABASE_URL}/auth/v1",
            "iat": now,
            "exp": now + timedelta(minutes=5),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


def make_pdf() -> bytes:
    document = fitz.open()
    page = document.new_page(width=612, height=792)
    page.draw_rect(fitz.Rect(48, 40, 150, 96), color=(0.05, 0.25, 0.5), fill=(0.05, 0.25, 0.5))
    page.insert_text((56, 74), "NUST", fontsize=24, fontname="hebo", color=(1, 1, 1))
    page.insert_text((50, 150), "Research Template", fontsize=18, fontname="hebo")
    page.insert_text((50, 205), "Study information and participant procedures.", fontsize=11)
    page.insert_text((50, 750), "Ethics reference: TEST-001", fontsize=9)
    output = document.tobytes()
    document.close()
    return output


def make_docx() -> bytes:
    document = Document()
    normal = document.styles["Normal"]
    normal.font.name = "Arial"
    normal.font.size = 11 * 12700
    document.styles["Heading 1"].font.name = "Arial"
    document.styles["Heading 1"].font.size = 14 * 12700
    document.add_heading("Research Template", level=1)
    document.add_paragraph("Study information and participant procedures.")
    document.sections[0].header.paragraphs[0].text = "Test Institution"
    document.sections[0].footer.paragraphs[0].text = "Ethics reference"
    output = BytesIO()
    document.save(output)
    return output.getvalue()


@pytest.fixture(autouse=True)
def configure_test_auth(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", JWT_SECRET)
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.setenv("SUPABASE_URL", SUPABASE_URL)
    monkeypatch.setenv("SUPABASE_ANON_KEY", SUPABASE_ANON_KEY)


def mock_storage_api(
    monkeypatch: pytest.MonkeyPatch,
    handler: Any,
) -> None:
    async_client = httpx.AsyncClient
    transport = httpx.MockTransport(handler)

    def make_client(**kwargs: Any) -> httpx.AsyncClient:
        return async_client(transport=transport, **kwargs)

    monkeypatch.setattr(storage.httpx, "AsyncClient", make_client)


def test_parse_storage_path_requires_bucket_and_object() -> None:
    parsed = storage.parse_storage_path("templates/research/sample.pdf")

    assert parsed.bucket == "templates"
    assert parsed.object_path == "research/sample.pdf"
    assert parsed.name == "sample.pdf"


@pytest.mark.parametrize(
    "storage_path",
    ["", "templates", "/templates/sample.pdf", "templates/../private.pdf", "templates\\sample.pdf"],
)
def test_parse_storage_path_rejects_invalid_paths(storage_path: str) -> None:
    with pytest.raises(HTTPException) as error:
        storage.parse_storage_path(storage_path)

    assert error.value.status_code == 422


def test_analyse_pdf_extracts_styles_and_logo_candidate() -> None:
    analysis = analyse_template("sample.pdf", make_pdf())

    assert analysis.style_spec["font"]
    assert analysis.style_spec["size_pt"] == 11
    assert analysis.style_spec["heading"]["size_pt"] >= 18
    assert analysis.style_spec["footer"] == "Ethics reference: TEST-001"
    assert analysis.confidence["font"] > 0
    assert analysis.logo_candidates
    assert analysis.logo_candidates[0].page == 1
    assert len(analysis.logo_candidates[0].bbox) == 4


def test_analyse_docx_extracts_styles_header_footer_and_margins() -> None:
    analysis = analyse_template("sample.docx", make_docx())

    assert analysis.style_spec["font"] == "Arial"
    assert analysis.style_spec["size_pt"] == 11
    assert analysis.style_spec["heading"]["size_pt"] == 14
    assert analysis.style_spec["margins_cm"]
    assert analysis.style_spec["header"] == "Test Institution"
    assert analysis.style_spec["footer"] == "Ethics reference"
    assert analysis.logo_candidates == []


def test_analyse_rejects_malformed_docx() -> None:
    output = BytesIO()
    with ZipFile(output, "w") as archive:
        archive.writestr("[Content_Types].xml", "<Types/>")
        archive.writestr("word/document.xml", "not XML")

    with pytest.raises(HTTPException) as error:
        analyse_template("sample.docx", output.getvalue())

    assert error.value.status_code == 422
    assert error.value.detail["code"] == "invalid_template"


def test_extract_logo_returns_png_with_requested_bbox() -> None:
    logo = extract_logo("sample.pdf", make_pdf(), page_number=1, crop=[48, 40, 150, 96])

    assert logo.png.startswith(b"\x89PNG\r\n\x1a\n")
    assert logo.bbox == [48.0, 40.0, 150.0, 96.0]
    assert logo.confidence == 0.95


@pytest.mark.parametrize(
    ("page", "crop"),
    [(0, None), (61, None), (1, [1000, 1000, 1100, 1100]), (1, [1, 2, 3])],
)
def test_extract_logo_rejects_invalid_page_or_crop(
    page: int, crop: list[float] | None
) -> None:
    with pytest.raises(HTTPException) as error:
        extract_logo("sample.pdf", make_pdf(), page, crop)

    assert error.value.status_code == 422


def test_analyse_endpoint_uses_caller_jwt_for_storage(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    headers = auth_headers()
    expected_token = headers["Authorization"]

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "GET"
        assert request.url.path == (
            "/storage/v1/object/authenticated/templates/research/sample.pdf"
        )
        assert request.headers["authorization"] == expected_token
        assert request.headers["apikey"] == SUPABASE_ANON_KEY
        return httpx.Response(200, content=make_pdf(), request=request)

    mock_storage_api(monkeypatch, handler)
    response = client.post(
        "/v1/templates/analyse",
        json={"storage_path": "templates/research/sample.pdf"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["font"]
    assert response.json()["confidence"]["font"] > 0
    assert response.json()["logo_candidates"]


def test_analyse_endpoint_requires_authentication() -> None:
    response = client.post(
        "/v1/templates/analyse",
        json={"storage_path": "templates/sample.pdf"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "unauthorized"


def test_extract_endpoint_writes_png_and_returns_storage_path(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    headers = auth_headers()
    expected_token = headers["Authorization"]
    uploaded: dict[str, Any] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["authorization"] == expected_token
        assert request.headers["apikey"] == SUPABASE_ANON_KEY
        if request.method == "GET":
            assert request.url.path == (
                "/storage/v1/object/authenticated/templates/research/sample.pdf"
            )
            return httpx.Response(200, content=make_pdf(), request=request)
        uploaded.update(path=request.url.path, content=request.content)
        return httpx.Response(200, json={"Key": "templates/logos/result.png"}, request=request)

    mock_storage_api(monkeypatch, handler)
    response = client.post(
        "/v1/logos/extract",
        json={
            "storage_path": "templates/research/sample.pdf",
            "page": 1,
            "crop": [48, 40, 150, 96],
        },
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["png_path"].startswith("templates/logos/")
    assert response.json()["bbox"] == [48.0, 40.0, 150.0, 96.0]
    assert uploaded["path"].startswith("/storage/v1/object/templates/logos/")
    assert uploaded["content"].startswith(b"\x89PNG\r\n\x1a\n")


def test_analyse_endpoint_rejects_missing_storage_path() -> None:
    response = client.post(
        "/v1/templates/analyse",
        json={},
        headers=auth_headers(),
    )

    assert response.status_code == 422
    assert response.json()["code"] == "invalid_request"
    assert response.json()["field"] == "storage_path"
