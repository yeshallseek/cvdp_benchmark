# DiffusionGemma mini-swe CVDP pilot

## Question

Can the NVFP4 DiffusionGemma checkpoint reliably operate mini-swe-agent and produce
gradeable CVDP patches when served at its maximum 256K-token context on one RTX 5090?

## Pilot scope

- Dataset: CVDP v1.1.0 agentic code generation, non-commercial
- Tasks: the 10 IDs in `pilot_ids.txt`
- Selection: deterministic balanced category/difficulty sampling, seed 42
- Agent: mini-swe-agent 2.3.1 `DefaultAgent`
- Worker count: 1
- Pass metric: all harness tests for a problem return zero

## Fixed configuration

- Model: `RedHatAI/diffusiongemma-26B-A4B-it-NVFP4`
- vLLM image: `vllm/vllm-openai:gemma`
- Maximum context: 262,144 tokens
- KV cache: FP8
- GPU memory utilization: 0.80
- CPU offload: 0 GB
- Maximum active sequences: 1
- Tool parser: `gemma4`
- Reasoning parser: `gemma4`
- Thinking: enabled
- Diffusion canvas: 256 tokens
- Entropy bound: 0.1
- Agent step limit: 60 model calls
- Per-call output limit: 16,384 tokens
- Per-command timeout: 300 seconds
- Outer agent timeout: 3,600 seconds
- Harness timeout: 900 seconds

## Recorded metrics

- CVDP pass/fail and category/difficulty
- outer `agent_execution` wall time from the CVDP harness
- in-agent `duration_seconds`
- mini-swe model-call count and exit status
- total pilot process wall time
- trajectory and patch artifacts for failure review

## Gates

1. The endpoint must return a native `bash` tool call before the benchmark starts.
2. The server must expose a 262,144-token maximum without CPU offload.
3. Run exactly 10 tasks and stop for review.
4. Treat this as a stochastic pass@1 pilot, not a final model ranking.

## Comparison

For the same 10 IDs, compare against the existing valid Nemotron artifacts in
`work_nemotron3`. Report pass count and median/mean outer agent duration for both models.
