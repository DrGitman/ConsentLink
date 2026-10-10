import pytest

from analysis import (
    load_outcome_csv,
    load_sus_csv,
    score_sus,
    summarize_language_outcomes,
    summarize_sus,
    summarize_sus_by_round,
)


def test_sus_all_strongly_agree_scores_fifty() -> None:
    assert score_sus([5] * 10) == 50.0


def test_sus_positive_and_negative_extremes_score_one_hundred_and_zero() -> None:
    assert score_sus([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]) == 100.0
    assert score_sus([1, 5, 1, 5, 1, 5, 1, 5, 1, 5]) == 0.0


def test_sus_does_not_impute_missing_responses() -> None:
    responses: list[int | None] = [3] * 9 + [None]

    assert score_sus(responses) is None


def test_sus_still_validates_answered_items_in_incomplete_rows() -> None:
    responses: list[int | None] = [3] * 8 + [6, None]

    with pytest.raises(ValueError, match="integer from 1 to 5"):
        score_sus(responses)


@pytest.mark.parametrize(
    "responses",
    [
        [3] * 9,
        [3] * 11,
        [3] * 9 + [0],
        [3] * 9 + [6],
        [3] * 9 + [3.5],  # type: ignore[list-item]
        [3] * 9 + [True],  # type: ignore[list-item]
    ],
)
def test_sus_rejects_invalid_complete_response_rows(responses: list[int]) -> None:
    with pytest.raises(ValueError):
        score_sus(responses)


def test_sus_summary_excludes_incomplete_responses_and_reports_count() -> None:
    complete = {f"item_{number}": response for number, response in enumerate([5, 1] * 5, 1)}
    incomplete = {**complete, "item_10": None}

    result = summarize_sus([complete, incomplete])

    assert result == {
        "complete_responses": 1,
        "incomplete_responses": 1,
        "mean": 100.0,
        "median": 100.0,
        "minimum": 100.0,
        "maximum": 100.0,
    }


def test_sus_summary_keeps_rounds_separate() -> None:
    round_one = {
        "round": "1",
        **{f"item_{number}": response for number, response in enumerate([5, 1] * 5, 1)},
    }
    round_two = {
        "round": "2",
        **{f"item_{number}": response for number, response in enumerate([1, 5] * 5, 1)},
    }

    result = summarize_sus_by_round([round_one, round_two])

    assert result["1"]["mean"] == 100.0
    assert result["2"]["mean"] == 0.0


def test_language_summary_reports_descriptive_success_and_comprehension_ratios() -> None:
    rows = [
        {
            "session_code": f"en-{number}",
            "round": "1",
            "language_code": "en",
            "task_id": "understand",
            "task_attempted": True,
            "task_success": number <= 4,
            "comprehension_correct": number <= 3,
        }
        for number in range(1, 5)
    ] + [
        {
            "session_code": f"af-{number}",
            "round": "1",
            "language_code": "af",
            "task_id": "understand",
            "task_attempted": True,
            "task_success": number <= 2,
            "comprehension_correct": number == 1,
        }
        for number in range(1, 5)
    ]

    result = summarize_language_outcomes(rows, min_group_size=2)
    task = result["rounds"]["1"]["tasks"]["understand"]

    assert task["task_success"]["lowest_to_highest_rate_ratio"] == 0.5
    assert task["comprehension"]["lowest_to_highest_rate_ratio"] == pytest.approx(1 / 3)
    assert result["interpretation"].startswith("Descriptive diagnostic only")


def test_language_summary_suppresses_groups_below_selected_minimum() -> None:
    rows = [
        {
            "session_code": "small-group-session",
            "round": "1",
            "language_code": "hz",
            "task_id": "listen",
            "task_attempted": True,
            "task_success": True,
            "comprehension_correct": None,
        },
        {
            "session_code": "large-1",
            "round": "1",
            "language_code": "en",
            "task_id": "listen",
            "task_attempted": True,
            "task_success": True,
            "comprehension_correct": True,
        },
        {
            "session_code": "large-2",
            "round": "1",
            "language_code": "en",
            "task_id": "listen",
            "task_attempted": True,
            "task_success": False,
            "comprehension_correct": False,
        },
    ]

    result = summarize_language_outcomes(rows, min_group_size=2)
    groups = result["rounds"]["1"]["tasks"]["listen"]["task_success"]["groups"]

    assert groups[0]["language_code"] == "en"
    assert groups[0]["participants"] == 2
    assert groups[1] == {
        "language_code": "hz",
        "suppressed": True,
        "participants": None,
        "successes": None,
        "rate": None,
    }
    assert (
        result["rounds"]["1"]["tasks"]["listen"]["task_success"][
            "suppressed_group_count"
        ]
        == 1
    )


def test_language_summary_handles_no_positive_outcome_without_division_by_zero() -> None:
    rows = [
        {
            "session_code": f"en-{number}",
            "round": "1",
            "language_code": "en",
            "task_id": "task",
            "task_attempted": True,
            "task_success": False,
            "comprehension_correct": False,
        }
        for number in range(2)
    ]

    result = summarize_language_outcomes(rows, min_group_size=1)

    assert (
        result["rounds"]["1"]["tasks"]["task"]["task_success"][
            "lowest_to_highest_rate_ratio"
        ]
        is None
    )


def test_language_summary_rejects_duplicate_or_inconsistent_rows() -> None:
    row = {
        "session_code": "session-1",
        "round": "1",
        "language_code": "en",
        "task_id": "task",
        "task_attempted": False,
        "task_success": True,
        "comprehension_correct": None,
    }

    with pytest.raises(ValueError, match="cannot succeed"):
        summarize_language_outcomes([row], min_group_size=1)

    valid = {**row, "task_attempted": True, "task_success": False}
    with pytest.raises(ValueError, match="Duplicate session/round/task"):
        summarize_language_outcomes([valid, valid], min_group_size=1)


def test_language_summary_allows_same_session_and_task_in_distinct_rounds() -> None:
    rows = [
        {
            "session_code": "session-1",
            "round": round_name,
            "language_code": "en",
            "task_id": "task",
            "task_attempted": True,
            "task_success": success,
            "comprehension_correct": None,
        }
        for round_name, success in [("1", False), ("2", True)]
    ]

    result = summarize_language_outcomes(rows, min_group_size=1)

    assert result["rounds"]["1"]["tasks"]["task"]["task_success"]["groups"][0]["rate"] == 0
    assert result["rounds"]["2"]["tasks"]["task"]["task_success"]["groups"][0]["rate"] == 1


def test_language_summary_requires_a_privacy_threshold() -> None:
    with pytest.raises(ValueError, match="positive integer"):
        summarize_language_outcomes([], min_group_size=0)


def test_csv_loaders_parse_anonymized_worksheet_exports(tmp_path) -> None:
    sus_path = tmp_path / "sus.csv"
    sus_path.write_text(
        "session_code,round," + ",".join(f"item_{number}" for number in range(1, 11))
        + "\nsession-a,2," + ",".join(["5", "1"] * 5) + "\n",
        encoding="utf-8",
    )
    outcome_path = tmp_path / "outcomes.csv"
    outcome_path.write_text(
        "session_code,round,language_code,task_id,task_attempted,task_success,comprehension_correct\n"
        "session-a,2,en,rights,true,true,\n",
        encoding="utf-8",
    )

    sus_rows = load_sus_csv(sus_path)
    outcome_rows = load_outcome_csv(outcome_path)

    assert summarize_sus(sus_rows)["mean"] == 100.0
    assert outcome_rows[0]["task_attempted"] is True
    assert outcome_rows[0]["task_success"] is True
    assert outcome_rows[0]["comprehension_correct"] is None


def test_csv_loader_rejects_invalid_boolean_values(tmp_path) -> None:
    outcome_path = tmp_path / "outcomes.csv"
    outcome_path.write_text(
        "session_code,round,language_code,task_id,task_attempted,task_success,comprehension_correct\n"
        "session-a,2,en,rights,yes,true,\n",
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="CSV row 2"):
        load_outcome_csv(outcome_path)
