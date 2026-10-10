from datetime import datetime, timedelta, timezone
from io import BytesIO
from zipfile import ZIP_STORED, ZipFile

import jwt
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)
JWT_SECRET = "test-secret-for-unit-tests-only-with-at-least-32-bytes"


def auth_headers(secret: str = JWT_SECRET) -> dict[str, str]:
    now = datetime.now(timezone.utc)
    token = jwt.encode(
        {
            "sub": "test-user",
            "role": "authenticated",
            "aud": "authenticated",
            "iat": now,
            "exp": now + timedelta(minutes=5),
        },
        secret,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


def make_docx(extra_files: dict[str, bytes] | None = None) -> bytes:
    output = BytesIO()
    with ZipFile(output, "w") as archive:
        archive.writestr("[Content_Types].xml", "<Types/>")
        archive.writestr("word/document.xml", "<document/>")
        for name, contents in (extra_files or {}).items():
            archive.writestr(name, contents)
    return output.getvalue()


def make_odt() -> bytes:
    output = BytesIO()
    with ZipFile(output, "w") as archive:
        archive.writestr("mimetype", "application/vnd.oasis.opendocument.text", ZIP_STORED)
        archive.writestr("content.xml", "<document/>")
    return output.getvalue()


@pytest.fixture(autouse=True)
def configure_test_auth(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", JWT_SECRET)
    monkeypatch.delenv("SUPABASE_URL", raising=False)


@pytest.mark.parametrize(
    ("filename", "contents", "detected_type"),
    [
        ("proposal.pdf", b"%PDF-1.7\n", "application/pdf"),
        ("proposal.docx", make_docx(), "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
        ("proposal.odt", make_odt(), "application/vnd.oasis.opendocument.text"),
        ("proposal.txt", b"Study purpose and procedures.\n", "text/plain"),
        ("scan.png", b"\x89PNG\r\n\x1a\nimage bytes", "image/png"),
    ],
)
def test_scan_accepts_supported_file_signatures(
    filename: str, contents: bytes, detected_type: str
) -> None:
    response = client.post(
        "/v1/files/scan",
        files={"file": (filename, contents)},
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json() == {
        "safe": True,
        "detected_type": detected_type,
        "size_mb": round(len(contents) / (1024 * 1024), 3),
        "reasons": [],
    }


@pytest.mark.parametrize(
    ("filename", "contents", "reason"),
    [
        ("malware.exe", b"MZ\x90\x00", "executable"),
        ("script.sh", b"#!/bin/sh\necho unsafe\n", "script"),
        ("corrupt.doc", b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1broken", "scan_error"),
        ("proposal.pdf", b"not a PDF", "unsupported_type"),
        ("proposal.docx", make_docx({"word/vbaProject.bin": b"test"}), "macro_found"),
        ("proposal.pdf", b"\x89PNG\r\n\x1a\nimage bytes", "signature_mismatch"),
        ("empty.txt", b"", "empty_file"),
    ],
)
def test_scan_rejects_unsafe_or_mismatched_files(
    filename: str, contents: bytes, reason: str
) -> None:
    response = client.post(
        "/v1/files/scan",
        files={"file": (filename, contents)},
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["safe"] is False
    assert reason in response.json()["reasons"]


def test_scan_requires_a_bearer_token() -> None:
    response = client.post(
        "/v1/files/scan",
        files={"file": ("proposal.pdf", b"%PDF-1.7\n")},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "unauthorized"


def test_scan_rejects_invalid_bearer_token() -> None:
    response = client.post(
        "/v1/files/scan",
        files={"file": ("proposal.pdf", b"%PDF-1.7\n")},
        headers={"Authorization": "Bearer invalid"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "unauthorized"


def test_scan_returns_contract_error_when_auth_is_unconfigured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("SUPABASE_JWT_SECRET")
    response = client.post(
        "/v1/files/scan",
        files={"file": ("proposal.pdf", b"%PDF-1.7\n")},
        headers=auth_headers(),
    )

    assert response.status_code == 503
    assert response.json()["code"] == "auth_not_configured"


def test_scan_rejects_files_over_25_mib() -> None:
    response = client.post(
        "/v1/files/scan",
        files={"file": ("proposal.pdf", b"%PDF-" + b"x" * (25 * 1024 * 1024))},
        headers=auth_headers(),
    )

    assert response.status_code == 413
    assert response.json()["code"] == "file_too_large"
    assert response.json()["field"] == "file"


def test_versioned_health_matches_api_contract() -> None:
    response = client.get("/v1/health")

    assert response.status_code == 200
    assert response.json() == {"ok": True, "version": "0.1.0"}


def test_missing_file_uses_shared_error_shape() -> None:
    response = client.post("/v1/files/scan", headers=auth_headers())

    assert response.status_code == 422
    assert response.json()["code"] == "invalid_request"
    assert response.json()["field"] == "file"
