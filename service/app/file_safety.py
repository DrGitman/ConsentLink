from dataclasses import dataclass
from io import BytesIO
from pathlib import PurePath
from zipfile import BadZipFile, ZipFile, is_zipfile
from zlib import error as ZlibError

from olefile.olefile import NotOleFileError, OleFileError
from oletools.olevba import VBA_Parser

MAX_FILE_SIZE = 25 * 1024 * 1024
MAX_ARCHIVE_SIZE = 50 * 1024 * 1024
MAX_ARCHIVE_MEMBER_COUNT = 10_000

EXECUTABLE_EXTENSIONS = {".com", ".dll", ".exe", ".jar", ".msi", ".scr"}
SCRIPT_EXTENSIONS = {
    ".bat",
    ".cmd",
    ".js",
    ".ps1",
    ".py",
    ".sh",
    ".vbe",
    ".vbs",
}
OLE_SIGNATURE = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"

ACCEPTED_EXTENSIONS = {
    "application/pdf": {".pdf"},
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": {
        ".docx"
    },
    "application/vnd.oasis.opendocument.text": {".odt"},
    "text/plain": {".txt"},
    "image/jpeg": {".jpg", ".jpeg"},
    "image/png": {".png"},
    "image/tiff": {".tif", ".tiff"},
}


@dataclass(frozen=True)
class ScanResult:
    detected_type: str
    reasons: list[str]


def _archive_members(content: bytes) -> tuple[set[str], ZipFile] | None:
    if not is_zipfile(BytesIO(content)):
        return None

    try:
        archive = ZipFile(BytesIO(content))
        members = archive.infolist()
    except BadZipFile:
        return None
    if len(members) > MAX_ARCHIVE_MEMBER_COUNT or sum(
        member.file_size for member in members
    ) > MAX_ARCHIVE_SIZE:
        archive.close()
        return None

    return {member.filename.lower() for member in members}, archive


def _contains_vba(filename: str, content: bytes) -> bool | None:
    parser: VBA_Parser | None = None
    try:
        parser = VBA_Parser(filename=filename, data=content)
        return parser.detect_vba_macros()
    except (
        AttributeError,
        BadZipFile,
        NotOleFileError,
        OleFileError,
        OSError,
        RuntimeError,
        ValueError,
    ):
        return None
    finally:
        if parser is not None:
            parser.close()


def _text_is_script(content: bytes) -> bool:
    prefix = content[:4096].lstrip(b"\xef\xbb\xbf \t\r\n")
    return prefix.startswith(b"#!") or prefix.lower().startswith(b"@echo off")


def _detect_type(filename: str, content: bytes) -> tuple[str, bool | None]:
    if content.startswith(b"%PDF-"):
        return "application/pdf", False
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png", False
    if content.startswith(b"\xff\xd8\xff"):
        return "image/jpeg", False
    if content.startswith((b"II*\x00", b"MM\x00*")):
        return "image/tiff", False
    if content.startswith(b"MZ") or content.startswith(b"\x7fELF") or content[
        :4
    ] in {
        b"\xfe\xed\xfa\xce",
        b"\xce\xfa\xed\xfe",
        b"\xfe\xed\xfa\xcf",
        b"\xcf\xfa\xed\xfe",
        b"\xca\xfe\xba\xbe",
        b"\xbe\xba\xfe\xca",
    }:
        return "application/x-executable", False

    if content.startswith(OLE_SIGNATURE):
        return "application/x-ole-storage", _contains_vba(filename, content)

    archive_info = _archive_members(content)
    if archive_info is not None:
        members, archive = archive_info
        try:
            if "word/document.xml" in members and "[content_types].xml" in members:
                has_vba_project = "word/vbaproject.bin" in members
                has_vba = _contains_vba(filename, content)
                return (
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    has_vba_project or has_vba,
                )
            if "mimetype" in members:
                mime_info = next(
                    (
                        member
                        for member in archive.infolist()
                        if member.filename.lower() == "mimetype"
                    ),
                    None,
                )
                if mime_info and mime_info.file_size <= 128:
                    try:
                        mime = archive.read(mime_info).decode("ascii", errors="ignore")
                    except (BadZipFile, OSError, RuntimeError, ValueError, ZlibError):
                        return "application/octet-stream", None
                    if mime == "application/vnd.oasis.opendocument.text":
                        has_script = any(
                            name.startswith(("basic/", "scripts/")) for name in members
                        )
                        return mime, has_script
        finally:
            archive.close()

    suffix = PurePath(filename).suffix.lower()
    if suffix == ".txt":
        try:
            content.decode("utf-8-sig")
            if b"\x00" not in content:
                return "text/plain", _text_is_script(content)
        except UnicodeDecodeError:
            pass

    return "application/octet-stream", False


def scan_file(filename: str, content: bytes) -> ScanResult:
    suffix = PurePath(filename).suffix.lower()
    detected_type, contains_macros_or_scripts = _detect_type(filename, content)
    reasons: list[str] = []

    if not content:
        reasons.append("empty_file")
    if suffix in EXECUTABLE_EXTENSIONS or detected_type == "application/x-executable":
        reasons.append("executable")
    if contains_macros_or_scripts is None:
        reasons.append("scan_error")
    if suffix in SCRIPT_EXTENSIONS or (
        detected_type == "text/plain" and contains_macros_or_scripts
    ):
        reasons.append("script")
    if (
        detected_type
        in {
            "application/x-ole-storage",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.oasis.opendocument.text",
        }
        and contains_macros_or_scripts
    ):
        reasons.append("macro_found")

    allowed_extensions = ACCEPTED_EXTENSIONS.get(detected_type)
    if allowed_extensions is None:
        if not reasons:
            reasons.append("unsupported_type")
    elif suffix not in allowed_extensions:
        reasons.append("signature_mismatch")

    return ScanResult(detected_type=detected_type, reasons=reasons)
