# DiffusionGemma mini-swe CVDP full evaluation

Approved: 2026-06-12

## Scope

- Dataset: all 92 tasks in CVDP v1.1.0 agentic code generation, non-commercial
- Model and agent settings: unchanged from the completed 10-task pilot
- Execution: one task at a time because the vLLM service uses `--max-num-seqs 1`
- Metric: pass@1, with all harness tests required to pass
- Comparison: the existing 92-task Nemotron run in `work_nemotron3`

## Runtime controls

- Maximum context: 262,144 tokens
- FP8 KV cache, 0.80 GPU memory utilization, no CPU offload
- mini-swe-agent 2.3.1, 60 model calls per task
- 16,384 maximum completion tokens per call
- 300-second command timeout
- 3,600-second outer agent timeout
- 900-second harness timeout

## Resumability

`scripts/run_diffusiongemma_full.sh` invokes the CVDP single-task path for each dataset ID.
After each task it verifies that the result was appended to `raw_result.json`. On restart,
IDs already present in that file are skipped. Per-task console logs are written under
`work_diffusiongemma_full92/task_logs/`.

## Expected duration and risks

- Pilot mean projects to about 10 hours of agent time for 92 tasks.
- Long-tail tasks can consume the full 60-call or 3,600-second budget.
- The primary observed risk is malformed or missing Gemma 4 tool calls, not VRAM capacity.
- Stop on infrastructure/API failure and resume after correcting it; do not silently count
  an endpoint outage as model performance.

## Completion gates

1. `raw_result.json` contains exactly the 92 authoritative dataset IDs.
2. Every task has outer agent timing in `report.json`.
3. Every completed agent has `mini_swe_agent_metrics.json` or an explicitly reported
   timeout/failure status.
4. The final timing summary, pass rate, category/difficulty split, and same-ID Nemotron
   comparison are recorded before declaring the evaluation complete.
