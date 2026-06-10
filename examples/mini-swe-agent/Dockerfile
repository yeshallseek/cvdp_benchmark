# mini-swe-agent CVDP agent backed by a self-hosted OpenAI-compatible endpoint.
# Build the simulation image first:
#   docker build -f docker/Dockerfile.sim -t nvidia/cvdp-sim:v1.0.0 .
FROM nvidia/cvdp-sim:v1.0.0

RUN pip install --no-cache-dir mini-swe-agent==2.3.1

COPY agent.py cvdp.yaml /app/

ENV MSWEA_CONFIG_PATH=/app/cvdp.yaml \
    MSWEA_COST_TRACKING=ignore_errors \
    MSWEA_SILENT_STARTUP=1

WORKDIR /code
ENTRYPOINT ["python3", "/app/agent.py"]
