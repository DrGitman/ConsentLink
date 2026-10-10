from __future__ import annotations

import csv
from collections import defaultdict
from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path
from statistics import mean, median
from typing import Any

SUS_ITEM_COUNT = 10
SUS_COLUMNS = ["session_code", "round", *[f"item_{number}" for number in range(1, 11)]]
OUTCOME_COLUMNS = [
    "session_code",
    "round",
    "language_code",
    "task_id",
    "task_attempted",
    "task_success",
    "comprehension_correct",
]


def _read_csv(path: str | Path, required_columns: Sequence[str]) -> list[dict[str, str]]:
    with Path(path).open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        if reader.fieldnames is None:
            raise ValueError("CSV file must include a header row.")
        missing = [column for column in required_columns if column not in reader.fieldnames]
        if missing:
            raise ValueError(f"CSV is missing required columns: {', '.join(missing)}.")
        return [dict(row) for row in reader]


def load_sus_csv(path: str | Path) -> list[dict[str, Any]]:
    """Load SUS responses from CSV, preserving blank items as unanswered."""
    rows: list[dict[str, Any]] = []
    for row_number, row in enumerate(_read_csv(path, SUS_COLUMNS), start=2):
        parsed: dict[str, Any] = {"session_code": row["session_code"], "round": row["round"]}
        for item_number in range(1, SUS_ITEM_COUNT + 1):
            raw = row[f"item_{item_number}"].strip()
            try:
                parsed[f"item_{item_number}"] = int(raw) if raw else None
            except ValueError as error:
                raise ValueError(
                    f"CSV row {row_number} item_{item_number} must be an integer from 1 to 5."
                ) from error
        rows.append(parsed)
    return rows


def load_outcome_csv(path: str | Path) -> list[dict[str, Any]]:
    """Load anonymized session/task outcomes with strict boolean parsing."""
    rows: list[dict[str, Any]] = []
    for row_number, row in enumerate(_read_csv(path, OUTCOME_COLUMNS), start=2):
        try:
            rows.append(
                {
                    "session_code": row["session_code"],
                    "round": row["round"],
                    "language_code": row["language_code"],
                    "task_id": row["task_id"],
                    "task_attempted": parse_bool(row["task_attempted"]),
                    "task_success": parse_bool(row["task_success"]),
                    "comprehension_correct": parse_bool(
                        row["comprehension_correct"], allow_empty=True
                    ),
                }
            )
        except ValueError as error:
            raise ValueError(f"CSV row {row_number}: {error}") from error
    return rows


def score_sus(responses: Sequence[int | None]) -> float | None:
    """Return a complete SUS score, or None when any response is unanswered."""
    if len(responses) != SUS_ITEM_COUNT:
        raise ValueError("SUS requires exactly 10 item responses.")

    if any(
        response is not None
        and (
            not isinstance(response, int)
            or isinstance(response, bool)
            or response not in range(1, 6)
        )
        for response in responses
    ):
        raise ValueError("Each completed SUS item response must be an integer from 1 to 5.")
    if any(response is None for response in responses):
        return None

    adjusted = [
        response - 1 if index % 2 == 0 else 5 - response
        for index, response in enumerate(responses)
    ]
    return sum(adjusted) * 2.5


def summarize_sus(
    response_rows: Iterable[Mapping[str, Any]],
) -> dict[str, int | float | None]:
    """Summarize SUS rows with item_1 through item_10, without imputing values."""
    scores: list[float] = []
    incomplete = 0

    for row in response_rows:
        responses = [row.get(f"item_{number}") for number in range(1, 11)]
        score = score_sus(responses)
        if score is None:
            incomplete += 1
        else:
            scores.append(score)

    return {
        "complete_responses": len(scores),
        "incomplete_responses": incomplete,
        "mean": mean(scores) if scores else None,
        "median": median(scores) if scores else None,
        "minimum": min(scores) if scores else None,
        "maximum": max(scores) if scores else None,
    }


def summarize_sus_by_round(
    response_rows: Iterable[Mapping[str, Any]],
) -> dict[str, dict[str, int | float | None]]:
    """Summarize SUS scores separately for each supplied study round."""
    by_round: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for index, row in enumerate(response_rows, start=1):
        round_name = row.get("round")
        if not isinstance(round_name, str) or not round_name.strip():
            raise ValueError(f"SUS row {index} requires a non-empty round label.")
        by_round[round_name.strip()].append(row)
    return {
        round_name: summarize_sus(rows)
        for round_name, rows in sorted(by_round.items())
    }


def parse_bool(value: str, *, allow_empty: bool = False) -> bool | None:
    normalized = value.strip().lower()
    if allow_empty and not normalized:
        return None
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    raise ValueError("Boolean CSV values must be 'true' or 'false'.")


def _validate_outcome_rows(
    rows: Iterable[Mapping[str, Any]],
) -> list[dict[str, Any]]:
    validated: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()

    for index, row in enumerate(rows, start=1):
        session_code = row.get("session_code")
        round_name = row.get("round")
        language_code = row.get("language_code")
        task_id = row.get("task_id")
        attempted = row.get("task_attempted")
        success = row.get("task_success")
        comprehension = row.get("comprehension_correct")

        if not all(
            isinstance(value, str) and value.strip()
            for value in (session_code, round_name, language_code, task_id)
        ):
            raise ValueError(
                f"Outcome row {index} requires session, round, language, and task codes."
            )
        if not isinstance(attempted, bool) or not isinstance(success, bool):
            raise ValueError(f"Outcome row {index} requires boolean attempt and success values.")
        if comprehension is not None and not isinstance(comprehension, bool):
            raise ValueError(
                f"Outcome row {index} comprehension_correct must be true, false, or None."
            )
        if success and not attempted:
            raise ValueError(f"Outcome row {index} cannot succeed when the task was not attempted.")
        if comprehension is not None and not attempted:
            raise ValueError(
                f"Outcome row {index} cannot have a comprehension result when not attempted."
            )

        key = (session_code.strip(), round_name.strip(), task_id.strip())
        if key in seen:
            raise ValueError(
                f"Duplicate session/round/task outcome in row {index}; "
                "provide one row per task in each round."
            )
        seen.add(key)
        validated.append(
            {
                "session_code": key[0],
                "round": key[1],
                "language_code": language_code.strip(),
                "task_id": task_id.strip(),
                "task_attempted": attempted,
                "task_success": success,
                "comprehension_correct": comprehension,
            }
        )
    return validated


def _group_metric(
    rows: Sequence[Mapping[str, Any]],
    *,
    metric: str,
    min_group_size: int,
) -> dict[str, Any]:
    groups: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for row in rows:
        groups[row["language_code"]].append(row)

    results: list[dict[str, Any]] = []
    eligible_rates: list[float] = []
    suppressed_groups = 0

    for language_code in sorted(groups):
        group = groups[language_code]
        denominators = [
            row
            for row in group
            if row["task_attempted"]
            and (metric != "comprehension_correct" or row[metric] is not None)
        ]
        participant_count = len({row["session_code"] for row in denominators})
        if participant_count < min_group_size:
            suppressed_groups += 1
            results.append(
                {
                    "language_code": language_code,
                    "suppressed": True,
                    "participants": None,
                    "successes": None,
                    "rate": None,
                }
            )
            continue

        successes = sum(bool(row[metric]) for row in denominators)
        rate = successes / participant_count
        eligible_rates.append(rate)
        results.append(
            {
                "language_code": language_code,
                "suppressed": False,
                "participants": participant_count,
                "successes": successes,
                "rate": rate,
            }
        )

    maximum_rate = max(eligible_rates, default=0.0)
    ratio = (
        min(eligible_rates) / maximum_rate
        if eligible_rates and maximum_rate > 0
        else None
    )
    return {
        "groups": results,
        "suppressed_group_count": suppressed_groups,
        "lowest_to_highest_rate_ratio": ratio,
    }


def summarize_language_outcomes(
    outcome_rows: Iterable[Mapping[str, Any]],
    *,
    min_group_size: int,
) -> dict[str, Any]:
    """Summarize descriptive language-group rates and a low/high diagnostic ratio.

    The ratio is descriptive only. It is not a fairness determination, statistical
    test, or guarantee of comparable outcomes.
    """
    if (
        not isinstance(min_group_size, int)
        or isinstance(min_group_size, bool)
        or min_group_size < 1
    ):
        raise ValueError("min_group_size must be a positive integer selected for the study.")

    rows = _validate_outcome_rows(outcome_rows)
    by_round: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for row in rows:
        by_round[row["round"]].append(row)

    return {
        "minimum_group_size": min_group_size,
        "rounds": {
            round_name: {
                "tasks": {
                    task_id: {
                        "task_success": _group_metric(
                            task_rows,
                            metric="task_success",
                            min_group_size=min_group_size,
                        ),
                        "comprehension": _group_metric(
                            task_rows,
                            metric="comprehension_correct",
                            min_group_size=min_group_size,
                        ),
                    }
                    for task_id, task_rows in sorted(
                        _group_rows_by_task(round_rows).items()
                    )
                }
            }
            for round_name, round_rows in sorted(by_round.items())
        },
        "interpretation": (
            "Descriptive diagnostic only; round results are not causal evidence. "
            "Small samples, missing groups, and confounding do not support a "
            "fairness conclusion."
        ),
    }


def _group_rows_by_task(
    rows: Iterable[Mapping[str, Any]],
) -> dict[str, list[Mapping[str, Any]]]:
    grouped: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[row["task_id"]].append(row)
    return grouped
