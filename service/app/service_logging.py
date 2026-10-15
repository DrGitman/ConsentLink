import json
import logging

logger = logging.getLogger("consentlink.service")


def log_service_event(level: int, event: str, **fields: str | int) -> None:
    record = {"event": event, **fields}
    logger.log(level, json.dumps(record, sort_keys=True, separators=(",", ":")))
