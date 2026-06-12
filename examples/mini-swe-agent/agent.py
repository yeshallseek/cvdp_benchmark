#!/usr/bin/env python3

# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

"""
mini-swe-agent runner for the CVDP agentic workflow.

Reads the task from /code/prompt.json and drives mini-swe-agent's DefaultAgent
with a LiteLLM model pointed at an OpenAI-compatible endpoint (e.g. a
self-hosted vLLM server on the Docker host).

Configuration (environment variables):
  MSWEA_MODEL_NAME   LiteLLM model name.
                     Default: hosted_vllm/RedHatAI/diffusiongemma-26B-A4B-it-NVFP4
  MSWEA_API_BASE     OpenAI-compatible base URL. Default: http://<docker-host-gateway>:8000/v1
  MSWEA_API_KEY      API key for the endpoint. Default: local-key
  MSWEA_STEP_LIMIT   Maximum number of model calls. Default: 60
  MSWEA_ENV_TIMEOUT  Per-command timeout in seconds. Default: 300
  MSWEA_CONFIG_PATH  Path to the YAML config. Default: /app/cvdp.yaml
"""

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import socket
import struct
import sys
import time
import traceback

# The benchmark runs this container with --user $UID:$GID, so $HOME from the
# image may be missing or read-only. Point cache/home at writable locations
# before litellm/minisweagent are imported.
if not os.environ.get("HOME") or not os.access(os.environ["HOME"], os.W_OK):
    os.environ["HOME"] = "/tmp"
os.environ.setdefault("XDG_CACHE_HOME", "/tmp/.cache")
os.environ.setdefault("MSWEA_COST_TRACKING", "ignore_errors")

import yaml

DEFAULT_MODEL = "hosted_vllm/RedHatAI/diffusiongemma-26B-A4B-it-NVFP4"
CONFIG_PATH = os.environ.get("MSWEA_CONFIG_PATH", "/app/cvdp.yaml")
TRAJECTORY_DIR_CANDIDATES = ["/code/rundir", "/tmp"]


def _docker_host_gateway():
    """Default-gateway IP of this container; on bridge networks this is the Docker host."""
    try:
        with open("/proc/net/route") as f:
            for line in f.readlines()[1:]:
                fields = line.split()
                # Destination 0.0.0.0 with the RTF_GATEWAY flag set
                if fields[1] == "00000000" and int(fields[3], 16) & 2:
                    return socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))
    except (OSError, IndexError, ValueError):
        pass
    return None


def _resolve_api_base():
    api_base = os.environ.get("MSWEA_API_BASE", "").strip()
    if api_base:
        return api_base

    gateway = _docker_host_gateway()
    if not gateway:
        print(
            "ERROR: could not detect the Docker host gateway; set MSWEA_API_BASE",
            file=sys.stderr,
        )
        sys.exit(1)
    return f"http://{gateway}:8000/v1"


def _artifact_path(filename):
    for candidate in TRAJECTORY_DIR_CANDIDATES:
        if os.path.isdir(candidate) and os.access(candidate, os.W_OK):
            return os.path.join(candidate, filename)
    return None


def _write_metrics(path, metrics):
    if not path:
        return
    try:
        Path(path).write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    except OSError as exc:
        print(f"Warning: could not write agent metrics to {path}: {exc}", file=sys.stderr)


def main():
    print("Starting mini-swe-agent CVDP runner...")

    try:
        with open("/code/prompt.json", "r") as f:
            task = json.load(f).get("prompt", "")
    except Exception as e:
        print(f"Error reading prompt.json: {e}", file=sys.stderr)
        sys.exit(1)

    if not task:
        print("No task found in prompt.json. Exiting.", file=sys.stderr)
        sys.exit(1)

    with open(CONFIG_PATH) as f:
        config = yaml.safe_load(f)

    api_base = _resolve_api_base()

    model_config = config.get("model", {})
    model_config["model_name"] = os.environ.get(
        "MSWEA_MODEL_NAME", model_config.get("model_name", DEFAULT_MODEL)
    )
    model_kwargs = model_config.setdefault("model_kwargs", {})
    model_kwargs["api_base"] = api_base
    model_kwargs.setdefault("api_key", os.environ.get("MSWEA_API_KEY", "local-key"))

    agent_config = config.get("agent", {})
    if os.environ.get("MSWEA_STEP_LIMIT"):
        agent_config["step_limit"] = int(os.environ["MSWEA_STEP_LIMIT"])
    trajectory = _artifact_path("mini_swe_agent_trajectory.json")
    metrics_path = _artifact_path("mini_swe_agent_metrics.json")
    if trajectory:
        agent_config["output_path"] = trajectory

    environment_config = config.get("environment", {})
    if os.environ.get("MSWEA_ENV_TIMEOUT"):
        environment_config["timeout"] = int(os.environ["MSWEA_ENV_TIMEOUT"])

    print(f"Model:       {model_config['model_name']}")
    print(f"API base:    {api_base}")
    print(f"Step limit:  {agent_config.get('step_limit')}")
    print(f"Trajectory:  {trajectory}")
    print(f"Metrics:     {metrics_path}")
    print(f"Task length: {len(task)} characters")
    sys.stdout.flush()

    from minisweagent.agents.default import DefaultAgent
    from minisweagent.environments.local import LocalEnvironment
    from minisweagent.models.litellm_model import LitellmModel

    agent = DefaultAgent(
        LitellmModel(**model_config),
        LocalEnvironment(**environment_config),
        **agent_config,
    )

    exit_status = "Error"
    exception_type = None
    exception_message = None
    started_at = datetime.now(timezone.utc)
    started = time.perf_counter()
    try:
        exit_info = agent.run(task)
        exit_status = exit_info.get("exit_status", "")
    except Exception as exc:
        exception_type = type(exc).__name__
        exception_message = str(exc)
        # Keep partial work: the harness evaluates whatever was changed.
        print("Agent terminated with an exception:", file=sys.stderr)
        traceback.print_exc()
    finally:
        finished_at = datetime.now(timezone.utc)
        duration_seconds = time.perf_counter() - started
        metrics = {
            "schema_version": 1,
            "started_at_utc": started_at.isoformat(),
            "finished_at_utc": finished_at.isoformat(),
            "duration_seconds": round(duration_seconds, 6),
            "model_name": model_config["model_name"],
            "api_base": api_base,
            "step_limit": agent_config.get("step_limit"),
            "exit_status": exit_status,
            "model_calls": agent.n_calls,
            "exception_type": exception_type,
            "exception_message": exception_message,
        }
        _write_metrics(metrics_path, metrics)

    print(
        "Agent finished: "
        f"exit_status={exit_status} model_calls={agent.n_calls} "
        f"duration_seconds={duration_seconds:.3f}"
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
