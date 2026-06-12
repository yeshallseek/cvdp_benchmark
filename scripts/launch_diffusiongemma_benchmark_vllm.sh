#!/usr/bin/env bash
set -euo pipefail

MODEL_ID="${MODEL_ID:-RedHatAI/diffusiongemma-26B-A4B-it-NVFP4}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-vllm/vllm-openai:gemma}"
CONTAINER_NAME="${CONTAINER_NAME:-diffusiongemma-vllm}"
PORT="${PORT:-8000}"
GPU_ID="${GPU_ID:-0}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-262144}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.80}"
KV_CACHE_DTYPE="${KV_CACHE_DTYPE:-fp8}"
HF_CACHE="${HF_CACHE:-${HOME}/.cache/huggingface}"

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Container ${CONTAINER_NAME} already exists. Stop or remove it first." >&2
  exit 1
fi

free_mib="$(
  nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits |
    awk -F, -v id="${GPU_ID}" '
      {
        gsub(/ /, "", $1);
        gsub(/ /, "", $2);
        if ($1 == id) print $2;
      }
    '
)"

if [[ -z "${free_mib}" || "${free_mib}" -lt 30000 ]]; then
  echo "GPU ${GPU_ID} needs at least 30000 MiB free; found ${free_mib:-unknown}." >&2
  exit 1
fi

echo "Serving ${MODEL_ID} at http://127.0.0.1:${PORT}/v1"
echo "Context=${MAX_MODEL_LEN}, KV cache=${KV_CACHE_DTYPE}, CPU offload=0, max sequences=1"

exec docker run --rm \
  --name "${CONTAINER_NAME}" \
  --ipc=host \
  --network host \
  --shm-size 16g \
  --gpus "device=${GPU_ID}" \
  --user "$(id -u):$(id -g)" \
  -e "CUDA_VISIBLE_DEVICES=${GPU_ID}" \
  -e "VLLM_USE_V2_MODEL_RUNNER=1" \
  -e "PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True" \
  -e "HOME=/tmp" \
  -e "USER=${USER:-ye}" \
  -e "LOGNAME=${LOGNAME:-${USER:-ye}}" \
  -e "HF_HOME=/hf-cache" \
  -e "TORCHINDUCTOR_CACHE_DIR=/tmp/torchinductor" \
  -e "TRITON_CACHE_DIR=/tmp/triton" \
  -v "${HF_CACHE}:/hf-cache" \
  "${CONTAINER_IMAGE}" \
  "${MODEL_ID}" \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --trust-remote-code \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs 1 \
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}" \
  --kv-cache-dtype "${KV_CACHE_DTYPE}" \
  --cpu-offload-gb 0 \
  --generation-config vllm \
  --hf-overrides '{"diffusion_sampler":"entropy_bound","diffusion_entropy_bound":0.1}' \
  --diffusion-config '{"canvas_length":256}' \
  --default-chat-template-kwargs '{"enable_thinking":true}' \
  --enable-chunked-prefill \
  --enable-auto-tool-choice \
  --tool-call-parser gemma4 \
  --reasoning-parser gemma4 \
  --chat-template /vllm-workspace/examples/tool_chat_template_gemma4.jinja
