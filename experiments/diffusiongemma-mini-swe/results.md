# DiffusionGemma mini-swe CVDP pilot results

Completed: 2026-06-12
Branch: `experiment/diffusiongemma-mini-swe-pilot`

## Headline

- DiffusionGemma: 4/10 passed (40%)
- Same-ID Nemotron baseline: 2/10 passed (20%)
- Total pilot wall time: 3,900.7 seconds (65.0 minutes)
- DiffusionGemma outer agent time: mean 388.6 seconds, median 88.0 seconds
- Nemotron outer agent time: mean 1,127.7 seconds, median 475.3 seconds

This is a balanced 10-task pilot, not a representative estimate for all 92 CVDP tasks.

## Per-task results

| Task | Difficulty | Result | Outer seconds | Model calls | Exit |
| --- | --- | ---: | ---: | ---: | --- |
| AES encryption/decryption 0003 | medium | fail | 1103.1 | 60 | limit |
| AES encryption/decryption 0009 | medium | fail | 1513.4 | 60 | limit |
| axis broadcaster 0001 | easy | pass | 141.3 | 60 | limit |
| barrel shifter 0002 | easy | pass | 9.3 | 13 | submitted |
| cipher 0001 | medium | pass | 22.4 | 26 | submitted |
| dynamic equalizer 0001 | hard | fail | 587.4 | 60 | limit |
| event storing 0001 | hard | fail | 34.7 | 23 | submitted |
| n-bit swizzling 0001 | easy | pass | 19.6 | 23 | submitted |
| swizzler 0005 | medium | fail | 448.8 | 60 | limit |
| traffic light controller 0001 | hard | fail | 6.2 | 5 | submitted |

Difficulty split: easy 3/3, medium 1/4, hard 0/3.

## Runtime verification

- vLLM accepted `max_model_len=262144`.
- FP8 KV cache capacity was 683,171 tokens at 0.80 GPU memory utilization.
- CPU offload remained disabled.
- The endpoint returned native Gemma 4 `bash` tool calls with parsed reasoning.
- A 0.95 memory-utilization launch was rejected after warmup OOM because vLLM allocated
  an unnecessary 1.12M-token KV cache. The final 0.80 setting preserves the full context
  limit and sampling-buffer headroom.

## Environment

- GPU: NVIDIA GeForce RTX 5090, 32,607 MiB
- Driver: 580.159.03
- vLLM: `0.22.1rc1.dev357+g74b5964f0`
- vLLM image ID: `sha256:9c719fc0c869092c7d0533f8357d6985a38d5ff03b20ffb6a4620c2b4806dd4b`
- mini-swe-agent: 2.3.1
- LiteLLM: 1.88.1
- CVDP Python: 3.13.5
- Agent image ID: `sha256:b236e302ad37c3ab391fed6da792cfc1ded5f38e304e25d4082b224269b12267`

## Agent behavior

- 390 total model calls; median 43 calls per task.
- 5/10 tasks self-submitted; 5/10 reached the 60-call limit.
- 57 tool-call format retries (14.6% of calls):
  - 56 responses had no usable parsed tool call.
  - 1 response omitted the required `command` argument.
- 5 responses exhausted the 16,384-token completion cap.
- Maximum observed prompt length: 69,873 tokens, 26.7% of the 262,144-token service limit.
- Total generated completion tokens: 408,785.

The primary pilot limitation was native tool-call/output reliability, not context capacity
or container overhead. Mean outer-minus-inner overhead was about 1.5 seconds per task.

## Same-ID baseline

Nemotron passed `barrel_shifter_0002` and `nbit_swizzling_0001`. DiffusionGemma passed
those two plus `axis_broadcaster_0001` and `cipher_0001`.

DiffusionGemma was about 2.9x faster by mean outer agent time and 5.4x faster by median on
these IDs. The comparison is noisy: Nemotron timed out on AES 0009 at 3,600 seconds, and
both models sampled stochastically.

## Decision

Stop after the requested 10 tasks. Do not start the 92-task run yet.

Before a full run, test a model-specific second pilot with a smaller completion cap and
explicit analysis of malformed Gemma 4 tool responses. The max-context deployment itself
is validated and does not need further memory tuning.

## Local artifacts

The generated run is intentionally ignored by git:

- Work directory: `work_diffusiongemma_pilot10/`
- Dataset SHA-256:
  `2007f4311ed731a985a4ed9187479ad2cfc2462bc4013eba0d72a9f35642fdcf`
- Pilot ID manifest SHA-256:
  `a3b50201af68d2e33ac547ff86b6e6a0704dac8c3fc767e3f7c5dbd9777852c5`
- Raw result SHA-256:
  `e0212a9759ba2fb6f5c807ce3097ab36598793d2c88e4dbecba561bea72d2c81`
- Timing summary SHA-256:
  `b6f5eb979f39008a0ee36ef94367eedca54e307ee6c2b4545ab14c402a936fc1`
