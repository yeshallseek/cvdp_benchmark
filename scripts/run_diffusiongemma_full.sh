#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

DATASET="${DATASET:-datasets/cvdp_v1.1.0_agentic_code_generation_no_commercial.jsonl}"
PREFIX="${PREFIX:-work_diffusiongemma_full92}"
AGENT_IMAGE="${AGENT_IMAGE:-cvdp-mini-swe-agent-diffusiongemma}"
MODEL_ID="${MODEL_ID:-RedHatAI/diffusiongemma-26B-A4B-it-NVFP4}"
API_BASE="${API_BASE:-http://127.0.0.1:8000/v1}"
EXPECTED_TASKS="${EXPECTED_TASKS:-92}"
DRY_RUN="${DRY_RUN:-0}"

mkdir -p "${PREFIX}/task_logs"

model_info="$(curl -fsS "${API_BASE}/models")"
model_id="$(jq -r '.data[0].id' <<<"${model_info}")"
max_model_len="$(jq -r '.data[0].max_model_len' <<<"${model_info}")"
if [[ "${model_id}" != "${MODEL_ID}" || "${max_model_len}" != "262144" ]]; then
  echo "Expected ${MODEL_ID} at 262144 tokens; found ${model_id} at ${max_model_len}." >&2
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
    {"role": "user", "content": "Print the current directory."}
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

mapfile -t task_ids < <(jq -r '.id' "${DATASET}")
if [[ "${#task_ids[@]}" -ne "${EXPECTED_TASKS}" ]]; then
  echo "Expected ${EXPECTED_TASKS} tasks in ${DATASET}; found ${#task_ids[@]}." >&2
  exit 1
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  completed_count=0
  if [[ -f "${PREFIX}/raw_result.json" ]]; then
    completed_count="$(jq 'length' "${PREFIX}/raw_result.json")"
  fi
  echo "Preflight passed: model=${model_id} context=${max_model_len}"
  echo "Dataset tasks=${#task_ids[@]} completed=${completed_count} prefix=${PREFIX}"
  exit 0
fi

IMAGE_NAME="${AGENT_IMAGE}" ./examples/mini-swe-agent/build_agent.sh

export MSWEA_MODEL_NAME="hosted_vllm/${MODEL_ID}"
export MSWEA_API_KEY="local-key"
export MSWEA_STEP_LIMIT="60"
export MSWEA_ENV_TIMEOUT="300"
export CVDP_AGENT_ENV="MSWEA_MODEL_NAME,MSWEA_API_KEY,MSWEA_STEP_LIMIT,MSWEA_ENV_TIMEOUT"

started_epoch_file="${PREFIX}/full_run_started_at_epoch.txt"
if [[ ! -f "${started_epoch_file}" ]]; then
  date +%s >"${started_epoch_file}"
fi

if [[ ! -f "${PREFIX}/run_metadata.json" ]]; then
  jq -n \
    --arg started_at_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg git_commit "$(git rev-parse HEAD)" \
    --arg git_branch "$(git branch --show-current)" \
    --arg dataset "${DATASET}" \
    --arg dataset_sha256 "$(sha256sum "${DATASET}" | awk '{print $1}')" \
    --arg model_id "${MODEL_ID}" \
    --arg api_base "${API_BASE}" \
    --arg agent_image "${AGENT_IMAGE}" \
    --arg agent_image_id "$(docker image inspect "${AGENT_IMAGE}" --format '{{.Id}}')" \
    --arg gpu "$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | head -n 1)" \
    --argjson expected_tasks "${EXPECTED_TASKS}" \
    '{
      started_at_utc: $started_at_utc,
      git_commit: $git_commit,
      git_branch: $git_branch,
      dataset: $dataset,
      dataset_sha256: $dataset_sha256,
      model_id: $model_id,
      api_base: $api_base,
      agent_image: $agent_image,
      agent_image_id: $agent_image_id,
      gpu: $gpu,
      expected_tasks: $expected_tasks,
      worker_count: 1,
      max_model_len: 262144,
      step_limit: 60,
      max_completion_tokens: 16384
    }' >"${PREFIX}/run_metadata.json"
fi

for index in "${!task_ids[@]}"; do
  task_id="${task_ids[$index]}"
  ordinal="$((index + 1))"

  if [[ -f "${PREFIX}/raw_result.json" ]] &&
    jq -e --arg id "${task_id}" 'has($id)' "${PREFIX}/raw_result.json" >/dev/null; then
    echo "[${ordinal}/${EXPECTED_TASKS}] Skipping completed ${task_id}"
    continue
  fi

  log_path="${PREFIX}/task_logs/${task_id}.log"
  echo "[${ordinal}/${EXPECTED_TASKS}] Starting ${task_id}"

  set +e
  "${ROOT}/cvdp_env/bin/python" run_benchmark.py \
    -f "${DATASET}" \
    -i "${task_id}" \
    -l \
    -g "${AGENT_IMAGE}" \
    -t 1 \
    -p "${PREFIX}" \
    2>&1 | tee "${log_path}"
  benchmark_status="${PIPESTATUS[0]}"
  set -e

  if [[ "${benchmark_status}" -ne 0 ]]; then
    echo "Task ${task_id} failed at the benchmark-process level; resume after inspection." >&2
    exit "${benchmark_status}"
  fi

  if [[ ! -f "${PREFIX}/raw_result.json" ]] ||
    ! jq -e --arg id "${task_id}" 'has($id)' "${PREFIX}/raw_result.json" >/dev/null; then
    echo "Task ${task_id} completed without a raw_result.json entry; stopping." >&2
    exit 1
  fi

  completed_count="$(jq 'length' "${PREFIX}/raw_result.json")"
  echo "[${ordinal}/${EXPECTED_TASKS}] Recorded ${task_id}; ${completed_count} total results"
done

completed_count="$(jq 'length' "${PREFIX}/raw_result.json")"
if [[ "${completed_count}" -ne "${EXPECTED_TASKS}" ]]; then
  echo "Expected ${EXPECTED_TASKS} final results; found ${completed_count}." >&2
  exit 1
fi

started_epoch="$(<"${started_epoch_file}")"
finished_epoch="$(date +%s)"
{
  echo "started_epoch=${started_epoch}"
  echo "finished_epoch=${finished_epoch}"
  echo "elapsed_seconds=$((finished_epoch - started_epoch))"
} >"${PREFIX}/benchmark_wall_time.txt"

"${ROOT}/cvdp_env/bin/python" tools/summarize_agent_timings.py "${PREFIX}"
