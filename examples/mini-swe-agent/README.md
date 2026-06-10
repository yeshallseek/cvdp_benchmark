# mini-swe-agent CVDP Agent

A minimal CVDP agent built on [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent),
designed for benchmarking self-hosted models served through any OpenAI-compatible endpoint
(e.g. vLLM on the Docker host).

The agent:

1. Reads the task from `/code/prompt.json`.
2. Runs mini-swe-agent's `DefaultAgent` with native bash tool-calling, executing commands
   directly inside the agent container (which includes Icarus Verilog, Verilator and Yosys
   from the `nvidia/cvdp-sim` base image, so the model can lint/simulate its own changes).
3. Exits 0 so the harness evaluates whatever was changed, even on agent errors or step limits.

## Build

```bash
# Base simulation image (once, from repo root)
docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 .

# Agent image
./examples/mini-swe-agent/build_agent.sh           # -> cvdp-mini-swe-agent
```

## Serve a model

Any OpenAI-compatible endpoint reachable from the Docker host works. Example with vLLM:

```bash
vllm serve nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4 \
  --host 0.0.0.0 --port 8000 \
  --reasoning-parser nemotron_v3 \
  --enable-auto-tool-choice --tool-call-parser qwen3_coder
```

By default the agent auto-detects the Docker host (the container's default gateway) and
targets `http://<gateway>:8000/v1`, so a server listening on `0.0.0.0:8000` on the host
needs no extra configuration. The endpoint must support native (OpenAI-style) tool calls.

## Run the benchmark

```bash
# Forward agent configuration env vars into the agent container (optional, defaults shown below)
export CVDP_AGENT_ENV=MSWEA_MODEL_NAME,MSWEA_API_BASE,MSWEA_API_KEY,MSWEA_STEP_LIMIT,MSWEA_ENV_TIMEOUT

python run_benchmark.py -f cvdp_v1.1.0_agentic_code_generation_no_commercial.jsonl \
  -l -g cvdp-mini-swe-agent

# Or multi-sample pass@k:
python run_samples.py -f dataset.jsonl -l -g cvdp-mini-swe-agent -n 5 -k 1
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `MSWEA_MODEL_NAME` | `hosted_vllm/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4` | LiteLLM model name (`hosted_vllm/` prefix for vLLM) |
| `MSWEA_API_BASE` | `http://<docker-host-gateway>:8000/v1` | OpenAI-compatible base URL |
| `MSWEA_API_KEY` | `local-key` | API key sent to the endpoint |
| `MSWEA_STEP_LIMIT` | `40` | Max model calls per datapoint |
| `MSWEA_ENV_TIMEOUT` | `300` | Per-command timeout (seconds) |
| `MSWEA_CONFIG_PATH` | `/app/cvdp.yaml` | Agent/model/environment YAML config |

Prompt templates, sampling parameters (`temperature: 0.6`, `top_p: 0.95`) and the
observation truncation policy live in [`cvdp.yaml`](cvdp.yaml).

## Debugging

Each run writes the full trajectory to `<work>/…/rundir/mini_swe_agent_trajectory.json`
(messages, tool calls, outputs), which is ignored by the harness's change tracking.
