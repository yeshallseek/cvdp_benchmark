#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
from statistics import mean, median


def task_id_from_metrics_path(path: Path) -> str:
    harness_id = int(path.parents[1].name)
    repository_id = path.parents[3].name
    return f"{repository_id}_{harness_id:04d}"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Summarize CVDP outer and in-agent timing metrics."
    )
    parser.add_argument("prefix", type=Path)
    args = parser.parse_args()

    report_path = args.prefix / "report.json"
    raw_result_path = args.prefix / "raw_result.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    raw_results = json.loads(raw_result_path.read_text(encoding="utf-8"))

    outer_by_id = {
        run["id"]: run for run in report.get("agent_details", {}).get("runs", [])
    }
    metrics_by_id = {}
    for path in args.prefix.glob("**/rundir/mini_swe_agent_metrics.json"):
        metrics_by_id[task_id_from_metrics_path(path)] = json.loads(
            path.read_text(encoding="utf-8")
        )

    rows = []
    for task_id, result in raw_results.items():
        tests = result.get("tests", [])
        passed = bool(tests) and result.get("errors") == 0 and all(
            test.get("result") == 0 for test in tests
        )
        outer = outer_by_id.get(task_id, {})
        metrics = metrics_by_id.get(task_id, {})
        rows.append(
            {
                "id": task_id,
                "category": result.get("category"),
                "difficulty": result.get("difficulty"),
                "passed": passed,
                "agent_status": outer.get("status", result.get("agent_status")),
                "outer_agent_seconds": outer.get(
                    "execution", result.get("agent_execution")
                ),
                "in_agent_seconds": metrics.get("duration_seconds"),
                "model_calls": metrics.get("model_calls"),
                "exit_status": metrics.get("exit_status"),
            }
        )

    rows.sort(key=lambda row: row["id"])
    outer_times = [
        row["outer_agent_seconds"]
        for row in rows
        if row["outer_agent_seconds"] is not None
    ]
    inner_times = [
        row["in_agent_seconds"]
        for row in rows
        if row["in_agent_seconds"] is not None
    ]
    summary = {
        "task_count": len(rows),
        "passed": sum(row["passed"] for row in rows),
        "pass_rate": sum(row["passed"] for row in rows) / len(rows) if rows else 0,
        "outer_agent_seconds": {
            "mean": mean(outer_times) if outer_times else None,
            "median": median(outer_times) if outer_times else None,
            "min": min(outer_times) if outer_times else None,
            "max": max(outer_times) if outer_times else None,
        },
        "in_agent_seconds": {
            "mean": mean(inner_times) if inner_times else None,
            "median": median(inner_times) if inner_times else None,
            "min": min(inner_times) if inner_times else None,
            "max": max(inner_times) if inner_times else None,
        },
        "runs": rows,
    }

    output_path = args.prefix / "agent_timing_summary.json"
    output_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    print(f"Tasks: {summary['task_count']}")
    print(f"Passed: {summary['passed']}/{summary['task_count']}")
    print(
        "Outer agent seconds: "
        f"mean={summary['outer_agent_seconds']['mean']:.3f} "
        f"median={summary['outer_agent_seconds']['median']:.3f}"
    )
    if inner_times:
        print(
            "In-agent seconds: "
            f"mean={summary['in_agent_seconds']['mean']:.3f} "
            f"median={summary['in_agent_seconds']['median']:.3f}"
        )
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
