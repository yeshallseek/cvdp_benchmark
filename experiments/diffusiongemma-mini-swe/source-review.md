# DiffusionGemma CVDP source review

Last reviewed: 2026-06-11

## Objective

Evaluate `RedHatAI/diffusiongemma-26B-A4B-it-NVFP4` as a mini-swe coding agent on
CVDP v1.1.0 agentic code generation, starting with a 10-task pilot before any full run.

## Primary sources

- Google model card:
  https://ai.google.dev/gemma/docs/diffusiongemma/model_card
- Red Hat NVFP4 checkpoint:
  https://huggingface.co/RedHatAI/diffusiongemma-26B-A4B-it-NVFP4
- vLLM Gemma 4 recipe:
  https://docs.vllm.ai/projects/recipes/en/latest/Google/Gemma4.html
- vLLM tool calling:
  https://docs.vllm.ai/en/latest/features/tool_calling/

## Relevant findings

- DiffusionGemma supports up to 256K tokens of context, native function calling, and
  thinking mode.
- The official sampling guidance uses entropy-bounded denoising with a 256-token canvas,
  entropy bound 0.1, and adaptive stopping.
- The NVFP4 checkpoint is the practical single-RTX-5090 path. CPU offload is disabled for
  this experiment.
- Gemma 4 function calling requires vLLM's `gemma4` tool parser. The local endpoint
  returned HTTP 400 for `tool_choice="required"` before that parser was enabled.
- The model's maximum context does not fit the prior BF16 KV-cache allocation on 32 GB
  VRAM. FP8 KV cache is therefore required to expose the full 262,144-token service limit.
- Diffusion inference is optimized for low concurrency. The benchmark uses
  `--max-num-seqs 1` and one CVDP worker.

## Prior benchmark control

The parent branch's valid Nemotron run used:

- mini-swe-agent 2.3.1
- 60 model calls per task
- 16,384 maximum output tokens per model call
- raw head/tail command observations
- 3,600-second outer agent timeout
- 900-second harness timeout
- final score: 19/92 problems passed (20.7%)

This pilot retains those agent and harness settings. Model-serving flags, required Gemma 4
tool parsing, model identity, and timing instrumentation are the intended differences.
