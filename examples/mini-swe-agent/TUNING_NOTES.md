# Tuning notes: Nemotron-3-Nano-Omni-30B on CVDP agentic non-commercial

## Round 1 (step_limit=40, max_tokens=8192, JSON observations)

Stopped after 20 finished datapoints; ran the test harness manually for those 20 and
fanned out one investigator subagent per trajectory.

**Results: 11/20 passed (55%).**

| Signal | Count | Verdict |
|---|---|---|
| Hit 40-step limit | 12/20 | 5 of them still passed; 0/20 judged "more steps would have flipped the result" — failures were thrash loops, not step starvation |
| Output truncation (`max_tokens`) | 2 incidents | silently truncated heredocs (rc=0, half-written file): one outright failure (DES), one recovered |
| Responses with no tool call | 55 (~8% of steps) | wasted steps; retried by harness |
| Context pressure | none | max prompt 33.6k of 131k |
| Wasted steps (loops/rewrites) | ~40% | dominant inefficiency |
| Premature submit without re-verification | 2 failures | DES, cache_controller |

**Root-cause bug found:** the observation template used Jinja's `|tojson`, which
HTML-escapes `<` `>` `&` into `\uXXXX` sequences. Verilog is full of `<<`/`<=`/`>>`,
so the model saw mangled file contents and wrote sed patterns against escaped text
that never matched the real file — one run burned 24 of 40 steps in that loop.

## Round 2 changes

- Observation template: raw text (no `|tojson`), head/tail truncation preserved.
- `step_limit`: 40 → 60 (safety margin; one passing run landed its fix on call 40/40).
- `max_tokens`: 8192 → 16384 (reasoning + long heredocs share the budget).
- Prompt: exactly-one-tool-call requirement, anti-loop guidance (never repeat a failing
  command; print the offending line or rewrite the file), write long files in parts and
  verify with `tail`, recompile changed files before submitting, keep scratch out of rtl/verif.
