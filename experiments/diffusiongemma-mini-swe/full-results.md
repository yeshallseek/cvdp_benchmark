# DiffusionGemma mini-swe full CVDP results

Completed: 2026-06-12
Branch: `experiment/diffusiongemma-mini-swe-pilot`
Run commit: `771a3a5efcee59a0c9b988255a66cae506409329`

## Headline

- DiffusionGemma: 25/92 passed (27.2%)
- Nemotron baseline: 19/92 passed (20.7%)
- Difference: +6 tasks, +6.5 percentage points
- Full DiffusionGemma wall time: 43,473 seconds (12h 4m 33s)
- DiffusionGemma agent time: mean 459.2 seconds, median 108.9 seconds
- Nemotron agent time: mean 852.7 seconds, median 491.4 seconds
- Aggregate agent time: 11.74 hours versus 21.79 hours

DiffusionGemma improved pass@1 by 31.6% relative to Nemotron while reducing aggregate
agent time by 46.1%. It was faster on 70/92 paired tasks.

## Paired outcomes

| Outcome | Tasks |
| --- | ---: |
| Both passed | 13 |
| DiffusionGemma only | 12 |
| Nemotron only | 6 |
| Neither passed | 61 |

The complete task-by-task pass, timing, status, model-call, and ratio comparison is in
`full-task-comparison.csv`.

## Difficulty

| Difficulty | Tasks | DiffusionGemma | Nemotron | DG mean seconds | Nemotron mean seconds |
| --- | ---: | ---: | ---: | ---: | ---: |
| easy | 17 | 10 (58.8%) | 9 (52.9%) | 131.6 | 628.6 |
| medium | 55 | 13 (23.6%) | 9 (16.4%) | 508.7 | 877.7 |
| hard | 20 | 2 (10.0%) | 1 (5.0%) | 601.4 | 974.5 |

## Category

| Category | Tasks | DiffusionGemma | Nemotron | DG mean seconds | Nemotron mean seconds |
| --- | ---: | ---: | ---: | ---: | ---: |
| cid003 | 34 | 10 | 11 | 498.8 | 486.2 |
| cid004 | 25 | 7 | 3 | 451.1 | 1296.6 |
| cid005 | 22 | 4 | 0 | 389.2 | 818.5 |
| cid016 | 11 | 4 | 5 | 495.2 | 1045.3 |

DiffusionGemma's gain came from `cid004` and `cid005`. Nemotron retained a one-task
advantage in both `cid003` and `cid016`.

## Runtime

- DiffusionGemma total outer agent time: 42,246.6 seconds
- Nemotron total outer agent time: 78,450.3 seconds
- Time saved: 36,203.7 seconds (10h 3m 24s)
- Mean speedup: 1.86x
- Median speedup: 4.51x
- Median paired task-time ratio: 0.225
- Fastest DiffusionGemma task: 4.9 seconds
- Longest DiffusionGemma task: 3,600.2 seconds
- Passing tasks: mean 53.2 seconds, median 14.5 seconds
- Failing tasks: mean 610.7 seconds, median 267.4 seconds

The benchmark wall time exceeded summed agent time by 1,226 seconds because task setup,
grading, Docker cleanup, and report generation run serially around each agent.

## Agent behavior

- 3,182 model calls were recorded across 91 completed agent metrics files.
- Median model calls per measured task: 29.
- 55 tasks self-submitted; 36 reached the 60-call limit.
- One task hit the 3,600-second outer agent timeout:
  `cvdp_agentic_axis_to_uart_0001`.
- One objective harness hit the 900-second Docker timeout:
  `cvdp_agentic_ethernet_mii_0006`.
- 502 missing-tool-call retries were observed, 15.8% of recorded model calls.
- 21 tool commands hit the configured 300-second command timeout.

Four tasks left already-timed-out `vvp` or `cat` subprocesses alive in the agent
container. Only detached children from completed tool calls were killed; active tool
shells, the agent process, and all benchmark time limits were left unchanged.

## Pass-set differences

DiffusionGemma-only passes:

- `cvdp_agentic_Min_Hamming_Distance_Finder_0001`
- `cvdp_agentic_async_fifo_compute_ram_application_0006`
- `cvdp_agentic_async_filo_0001`
- `cvdp_agentic_axi4lite_to_pcie_config_0003`
- `cvdp_agentic_cipher_0001`
- `cvdp_agentic_dual_port_memory_0004`
- `cvdp_agentic_event_scheduler_0001`
- `cvdp_agentic_event_scheduler_0004`
- `cvdp_agentic_fixed_arbiter_0010`
- `cvdp_agentic_jpeg_runlength_enc_0001`
- `cvdp_agentic_low_power_channel_0001`
- `cvdp_agentic_universal_shift_reg_0003`

Nemotron-only passes:

- `cvdp_agentic_axis_to_uart_0001`
- `cvdp_agentic_barrel_shifter_0002`
- `cvdp_agentic_byte_enable_ram_0002`
- `cvdp_agentic_monte_carlo_0006`
- `cvdp_agentic_sigma_delta_audio_0001`
- `cvdp_agentic_signed_comparator_0001`

## Interpretation

On this pass@1 run, DiffusionGemma is the stronger result: six more solved tasks and
about ten fewer aggregate agent-hours. The result is still low in absolute terms, with
67/92 tasks failing and 36 tasks exhausting the model-call budget.

The prior balanced pilot scored 4/10, while the same ten IDs scored 2/10 when sampled
again inside this full run. That variance reinforces that single-run pass@1 differences
should not be treated as deterministic task-level capability.

The main operational weakness remains tool reliability. Missing tool calls and long
self-tests consumed substantial budget even though context capacity and GPU memory
remained stable for the full run.

## Environment

- Model: `RedHatAI/diffusiongemma-26B-A4B-it-NVFP4`
- GPU: NVIDIA GeForce RTX 5090, 32,607 MiB
- Driver: 580.159.03
- Maximum context: 262,144 tokens
- KV cache: FP8
- GPU memory utilization: 0.80
- CPU offload: 0 GB
- Worker count: 1
- Agent step limit: 60 model calls
- Command timeout: 300 seconds
- Agent timeout: 3,600 seconds
- Harness timeout: 900 seconds

## Local artifacts

Generated run artifacts remain ignored under `work_diffusiongemma_full92/`.

- Dataset SHA-256:
  `2007f4311ed731a985a4ed9187479ad2cfc2462bc4013eba0d72a9f35642fdcf`
- Raw result SHA-256:
  `f7ca17c8aea4226899afcc4cce412ef4ddb787e9fde674db38d50d9657fda312`
- Timing summary SHA-256:
  `d46f5d32265b2e59446c1925c6a1a0eb3d1525a56519657b9be603897451ff24`
- Run metadata SHA-256:
  `cc13df095a60ccf74212594c8d60efaec5a146deb5a54d117e0dbaf5182475c8`
- CVDP report SHA-256:
  `d10158ec9f134786286a9622521416abf29a7a4d69e224cd7cfca10bb4699b4b`
- Task comparison CSV SHA-256:
  `5ab32402ba31db17fc70caaa5b55e9639a82df8ec0f6d88e6e7a2d5ca02af295`
