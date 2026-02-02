# INTERNAL_PROTOCOLS

This document defines the internal runner execution protocol for PR#1.

## Runnerd HTTP API (v1)

### POST /v1/runs

Request body (`RunRequest`):

- `run_id`: string (regex `^[a-zA-Z0-9_-]{8,64}$`)
- `lab_id`: string
- `submission_id`: string
- `command`: string[] (argv, non-empty)
- `allowed_executables`: string[] (deny-by-default allowlist)
- `limits`:
  - `timeout_s`: int
  - `cpu`: float
  - `mem_mb`: int
  - `pids`: int
- `env`: object (only `RBK_*` keys are forwarded)

Response (`RunResponse`) (HTTP 200 on success path, including terminal failures):

- `status`: one of
  - `OK`
  - `FAILED`
  - `TIMEOUT`
  - `RESOURCE_LIMIT`
  - `INVALID_REQUEST`
  - `INVALID_COMMAND`
  - `DOCKER_EXEC_FAILED`
  - `RUNNING`
- `reason`: one of
  - `NONE`
  - `INVALID_PAYLOAD`
  - `WORKSPACE_INVALID`
  - `IN_SYMLINK_DETECTED`
  - `COMMAND_FORMAT_NOT_ARGV`
  - `EXECUTABLE_NOT_ALLOWED`
  - `ARGUMENT_NOT_ALLOWED`
  - `DOCKER_EXEC_FAILED`
  - `TIMEOUT_HARD`
  - `PIDS_LIMIT`
  - `MEMORY_LIMIT`
  - `OUTPUT_LIMIT_EXCEEDED`
  - `SYMLINK_ESCAPE_ATTEMPT`
  - `ARTIFACT_WRITE_FAILED`

Errors:

- HTTP 400 for invalid request/command (with structured `detail` payload)
- HTTP 404 for unknown run_id
- HTTP 500 only for runnerd internal errors (never for missing artifacts)

### GET /v1/runs/{run_id}

Returns the last known `out/result.json` if it exists, otherwise a deterministic state:

- `RUNNING` if a non-stale lock exists
- `FAILED/WORKSPACE_INVALID` if workspace invalid
- `FAILED/DOCKER_EXEC_FAILED` if unknown state

## Workspace Layout

Runner workspaces are derived solely from:

- `RUNNERD_WORKSPACES_DIR` (default `/workspaces`)
- `run_id`

Structure:

- `<workspace>/<run_id>/in` (mounted read-only into container as `/workspace/in`)
- `<workspace>/<run_id>/out` (mounted read-write into container as `/workspace/out`)

Runnerd never mounts the repo into the sandbox.

## Docker Sandbox Policy

Runnerd executes:

- `docker run --network none --read-only --cap-drop ALL --security-opt no-new-privileges ...`
- `/workspace/in` is mounted `:ro`
- `/workspace/out` is mounted `:rw`

The container root filesystem is read-only; only `/workspace/out` is writable.

## Artifacts Contract (Model A)

Source-of-truth is `out/result.json` (written by runnerd).

Runner-base writes:

- `out/result.raw.json`
- `out/logs.jsonl`

Runnerd writes:

- `out/result.json` (final)
- `out/system.jsonl` (runnerd-only events)

### out/result.raw.json (runner-base)

Written by `/runner/entrypoint.py` inside the sandbox.

Schema:

- `exit_code`: int|null
- `started_at`: RFC3339 UTC string
- `finished_at`: RFC3339 UTC string
- `argv`: string[]
- `limits`: object (parsed from `RBK_LIMITS_JSON`)
- `truncated_logs`: boolean
- `runner_version`: string (optional)
- `error`: string|null (optional; set if entrypoint fails)

### out/result.json (runnerd final)

Runnerd writes this after docker execution finishes.

Schema:

- `status`: `RunStatus`
- `reason`: `RunReason`
- `exit_code`: int|null
- `started_at`, `finished_at`: RFC3339 UTC
- `argv`: string[] (echo of request command)
- `limits`: object (echo of request limits)
- `truncated_logs`: boolean
- `artifacts`: string[] (relative paths; at minimum `out/result.raw.json` and `out/logs.jsonl`; includes `out/system.jsonl` if present)
- `stderr_snippet`: string|null

Important:

- `TIMEOUT` / `RESOURCE_LIMIT` are determined by runnerd when artifacts exist.
- If `out/result.raw.json` is missing or invalid, runnerd must produce `FAILED/ARTIFACT_WRITE_FAILED`.
- `FAILED/DOCKER_EXEC_FAILED` is reserved for `docker run` failures.

### out/logs.jsonl (runner-base)

Each line is a JSON object:

- `ts`: RFC3339 UTC string
- `stream`: `stdout` | `stderr` | `system`
- `message`: string
- `truncated`: boolean

START/END:

- `{"ts":"...","stream":"system","message":"START","truncated":false}`
- `{"ts":"...","stream":"system","message":"END","truncated":false}`

TRUNCATED (must be the last line when present):

- `{"ts":"...","stream":"system","message":"TRUNCATED","truncated":true,"reason":"MAX_BYTES"}`

## Quotas and Deterministic Truncation

### Logs max bytes (`RBK_MAX_LOG_BYTES`)

Runner-base enforces a hard maximum log size.

Rule:

- Let `N = RBK_MAX_LOG_BYTES`.
- Runner-base computes `RESERVED_BYTES` as the UTF-8 byte length of the TRUNCATED line.
- `RBK_MAX_LOG_BYTES` must be >= `RESERVED_BYTES` (runner-base fails fast otherwise).
- It writes normal lines only up to `N - RESERVED_BYTES`.
- If any line would exceed `N - RESERVED_BYTES`, logging switches to truncated mode.
- After attempting to write END, runner-base writes the TRUNCATED line as the last line using the reserved budget.

### Output directory max bytes (`runnerd_max_out_bytes`)

Runnerd enforces a hard maximum total bytes under `out/`.

If exceeded:

- runnerd sets `status=RESOURCE_LIMIT`
- runnerd sets `reason=OUTPUT_LIMIT_EXCEEDED`

## Heuristic Resource Limit Hints (OOM/PIDS)

OOM and PIDS are heuristic and must not be presented as guaranteed.

Runnerd may set:

- `RESOURCE_LIMIT/MEMORY_LIMIT` only if `stderr_snippet` matches one of:
  - `\boom\b`
  - `\bout of memory\b`
  - `\bmemory limit\b`
  - `\bkilled\s+process\b`
  - `\bexit code\s+137\b`

- `RESOURCE_LIMIT/PIDS_LIMIT` only if `stderr_snippet` matches one of:
  - `\bfork\b.*\bresource temporarily unavailable\b`
  - `\bresource temporarily unavailable\b`
  - `\bcan't start new thread\b`
  - `\bunable to create new native thread\b`
  - `\bprocess limit\b`

If no strict pattern matches, runnerd must fall back to:

- `FAILED/DOCKER_EXEC_FAILED` (or `FAILED/NONE` if raw exit_code indicates a normal non-zero).
