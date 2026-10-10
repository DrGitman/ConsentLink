import os
from dataclasses import dataclass
from urllib.parse import quote

import httpx
from fastapi import HTTPException

from app.file_safety import MAX_FILE_SIZE

STORAGE_TIMEOUT_SECONDS = 20


@dataclass(frozen=True)
class StorageObject:
    bucket: str
    object_path: str

    @property
    def name(self) -> str:
        return self.object_path.rsplit("/", 1)[-1]


def parse_storage_path(storage_path: str) -> StorageObject:
    parts = storage_path.split("/")
    if (
        len(parts) < 2
        or not parts[0]
        or any(part in {"", ".", ".."} for part in parts[1:])
        or "\\" in storage_path
        or "?" in storage_path
        or "#" in storage_path
        or not all(character.isalnum() or character in "._-" for character in parts[0])
    ):
        raise HTTPException(
            status_code=422,
            detail={
                "code": "invalid_storage_path",
                "message": "Use a storage path in bucket/object/path format.",
                "field": "storage_path",
            },
        )
    return StorageObject(bucket=parts[0], object_path="/".join(parts[1:]))


def _storage_configuration(access_token: str) -> tuple[str, dict[str, str]]:
    base_url = os.getenv("SUPABASE_URL", "").rstrip("/")
    anon_key = os.getenv("SUPABASE_ANON_KEY", "")
    if not base_url or not anon_key:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "storage_not_configured",
                "message": "Supabase Storage is not configured.",
            },
        )
    return base_url, {
        "apikey": anon_key,
        "Authorization": f"Bearer {access_token}",
    }


def _raise_storage_error(error: httpx.HTTPStatusError) -> None:
    status = error.response.status_code
    if status == 404:
        code, message = "storage_object_not_found", "The requested storage object was not found."
    elif status in {401, 403}:
        code, message = "storage_forbidden", "The caller cannot access this storage object."
    else:
        code, message = "storage_request_failed", "Supabase Storage could not process the request."
    raise HTTPException(status_code=status, detail={"code": code, "message": message}) from error


async def download_storage_object(
    storage_path: str, access_token: str
) -> tuple[StorageObject, bytes]:
    stored_object = parse_storage_path(storage_path)
    base_url, headers = _storage_configuration(access_token)
    object_path = quote(
        f"{stored_object.bucket}/{stored_object.object_path}", safe="/"
    )
    url = f"{base_url}/storage/v1/object/authenticated/{object_path}"

    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(STORAGE_TIMEOUT_SECONDS)
        ) as client:
            async with client.stream("GET", url, headers=headers) as response:
                response.raise_for_status()
                content = bytearray()
                async for chunk in response.aiter_bytes():
                    content.extend(chunk)
                    if len(content) > MAX_FILE_SIZE:
                        raise HTTPException(
                            status_code=413,
                            detail={
                                "code": "file_too_large",
                                "message": "The source file exceeds the 25 MB limit.",
                                "field": "storage_path",
                            },
                        )
                return stored_object, bytes(content)
    except httpx.HTTPStatusError as error:
        _raise_storage_error(error)
    except httpx.TimeoutException as error:
        raise HTTPException(
            status_code=504,
            detail={"code": "storage_timeout", "message": "Supabase Storage timed out."},
        ) from error
    except httpx.RequestError as error:
        raise HTTPException(
            status_code=502,
            detail={
                "code": "storage_unavailable",
                "message": "Supabase Storage could not be reached.",
            },
        ) from error


async def upload_storage_object(
    source: StorageObject,
    object_path: str,
    content: bytes,
    access_token: str,
) -> str:
    base_url, headers = _storage_configuration(access_token)
    encoded_path = quote(f"{source.bucket}/{object_path}", safe="/")
    headers = {
        **headers,
        "Content-Type": "image/png",
        "x-upsert": "true",
    }
    url = f"{base_url}/storage/v1/object/{encoded_path}"

    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(STORAGE_TIMEOUT_SECONDS)
        ) as client:
            response = await client.post(url, headers=headers, content=content)
            response.raise_for_status()
    except httpx.HTTPStatusError as error:
        _raise_storage_error(error)
    except httpx.TimeoutException as error:
        raise HTTPException(
            status_code=504,
            detail={"code": "storage_timeout", "message": "Supabase Storage timed out."},
        ) from error
    except httpx.RequestError as error:
        raise HTTPException(
            status_code=502,
            detail={
                "code": "storage_unavailable",
                "message": "Supabase Storage could not be reached.",
            },
        ) from error

    return f"{source.bucket}/{object_path}"
