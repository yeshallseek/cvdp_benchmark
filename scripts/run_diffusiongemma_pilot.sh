#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

SOURCE_DATASET="${SOURCE_DATASET:-datasets/cvdp_v1.1.0_agentic_code_generation_no_commercial.jsonl}"
PILOT_DATASET="${PILOT_DATASET:-datasets/cvdp_diffusiongemma_pilot10.jsonl}"
PILOT_IDS="${PILOT_IDS:-experiments/diffusiongemma-mini-swe/pilot_ids.txt}"
PREFIX="${PREFIX:-work_diffusiongemma_pilot10}"
AGENT_IMAGE="${AGENT_IMAGE:-cvdp-mini-swe-agent-diffusiongemma}"
MODEL_ID="${MODEL_ID:-RedHatAI/diffusiongemma-26B-A4B-it-NVFP4}"
API_BASE="${API_BASE:-http://127.0.0.1:8000/v1}"

if [[ -e "${PREFIX}" ]]; then
  echo "Output prefix ${PREFIX} already exists; choose a new PREFIX." >&2
  exit 1
fi

model_id="$(curl -fsS "${API_BASE}/models" | jq -r '.data[0].id')"
if [[ "${model_id}" != "${MODEL_ID}" ]]; then
  echo "Expected endpoint model ${MODEL_ID}, found ${model_id}." >&2
  exit 1
fi

tool_response="$(
  curl -fsS "${API_BASE}/chat/completions" \
    -H 'Content-Type: application/json' \
    -d @- <<JSON
{
  "model": "${MODEL_ID}",
  "messages": [
    {"role": "system", "content": "Use the bash tool exactly once."},
    {"role": "user", "content": "List the current directory."}
  ],
  "tools": [{
    "type": "function",
    "function": {
      "name": "bash",
      "description": "Execute a bash command",
      "parameters": {
        "type": "object",
        "properties": {"command": {"type": "string"}},
        "required": ["command"]
      }
    }
  }],
  "tool_choice": "required",
  "temperature": 0.1,
  "max_tokens": 512
}
JSON
)"

if ! jq -e '.choices[0].message.tool_calls[0].function.name == "bash"' \
  >/dev/null <<<"${tool_response}"; then
  echo "DiffusionGemma endpoint did not return the required bash tool call:" >&2
  jq . <<<"${tool_response}" >&2
  exit 1
fi

rm -f "${PILOT_DATASET}"
"${ROOT}/cvdp_env/bin/python" tools/dataset_subset_creator.py \
  "${SOURCE_DATASET}" "${PILOT_DATASET}" \
  --include-ids-file "${PILOT_IDS}" \
  --no-reports --no-outputs

task_count="$(wc -l < "${PILOT_DATASET}")"
if [[ "${task_count}" -ne 10 ]]; then
  echo "Expected 10 pilot tasks, created ${task_count}." >&2
  exit 1
fi

IMAGE_NAME="${AGENT_IMAGE}" ./examples/mini-swe-agent/build_agent.sh

export MSWEA_MODEL_NAME="hosted_vllm/${MODEL_ID}"
export MSWEA_API_KEY="local-key"
export MSWEA_STEP_LIMIT="60"
export MSWEA_ENV_TIMEOUT="300"
export CVDP_AGENT_ENV="MSWEA_MODEL_NAME,MSWEA_API_KEY,MSWEA_STEP_LIMIT,MSWEA_ENV_TIMEOUT"

mkdir -p "${PREFIX}"
/usr/bin/time -f 'elapsed_seconds=%e\nuser_seconds=%U\nsystem_seconds=%S\nmax_rss_kib=%M' \
  -o "${PREFIX}/benchmark_wall_time.txt" \
  "${ROOT}/cvdp_env/bin/python" run_benchmark.py \
    -f "${PILOT_DATASET}" \
    -l \
    -g "${AGENT_IMAGE}" \
    -t 1 \
    -p "${PREFIX}"

"${ROOT}/cvdp_env/bin/python" tools/summarize_agent_timings.py "${PREFIX}"
