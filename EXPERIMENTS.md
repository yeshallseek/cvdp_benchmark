# Experiments

## DiffusionGemma mini-swe CVDP pilot

- Date: 2026-06-12
- Branch: `experiment/diffusiongemma-mini-swe-pilot`
- Base commit: `0e9ef5ac9560ccdc91fd3798b59113618f6edd33`
- Model: `RedHatAI/diffusiongemma-26B-A4B-it-NVFP4`
- Mode: CVDP v1.1.0 agentic code generation, 10-task pass@1 pilot
- Result: 4/10 passed
- Full report: `experiments/diffusiongemma-mini-swe/results.md`
- Source review: `experiments/diffusiongemma-mini-swe/source-review.md`
- Evaluation plan: `experiments/diffusiongemma-mini-swe/eval-plan.md`
- Fixed task IDs: `experiments/diffusiongemma-mini-swe/pilot_ids.txt`

Run the backend and pilot from the repository root:

```bash
./scripts/launch_diffusiongemma_benchmark_vllm.sh
./scripts/run_diffusiongemma_pilot.sh
```

The first command is long-running. Start the second command in another shell after
`http://127.0.0.1:8000/health` reports ready.

Generated benchmark artifacts remain local and ignored under
`work_diffusiongemma_pilot10/`. The result report records their hashes and summary so the
completed run can be identified without committing trajectories, patches, logs, or copied
benchmark repositories.

## DiffusionGemma full CVDP evaluation

- Completed: 2026-06-12
- Scope: all 92 non-commercial agentic tasks
- Result: 25/92 passed (27.2%)
- Nemotron baseline: 19/92 passed (20.7%)
- Wall time: 12h 4m 33s
- Full report: `experiments/diffusiongemma-mini-swe/full-results.md`
- Per-task comparison: `experiments/diffusiongemma-mini-swe/full-task-comparison.csv`
- Plan: `experiments/diffusiongemma-mini-swe/full-eval-plan.md`
- Runner: `scripts/run_diffusiongemma_full.sh`
- Local output: `work_diffusiongemma_full92/`

The full runner is resumable and preserves a separate console log for every task:

```bash
./scripts/run_diffusiongemma_full.sh
```
