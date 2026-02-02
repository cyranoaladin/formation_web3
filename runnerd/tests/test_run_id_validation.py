"""runnerd run_id validation tests."""

from __future__ import annotations


def test_run_id_regex_rejects_invalid(runnerd_client):
    resp = runnerd_client.post(
        "/v1/runs",
        json={
            "run_id": "../../etc/passwd",
            "lab_id": "lab_demo",
            "submission_id": "sub_demo",
            "command": ["python3", "-c", "print('OK')"],
            "allowed_executables": ["python3"],
            "limits": {"timeout_s": 5, "cpu": 1.0, "mem_mb": 256, "pids": 128},
            "env": {"RBK_FOO": "bar"},
        },
    )

    assert resp.status_code == 400
    body = resp.json()
    detail = body.get("detail") or {}
    assert detail.get("status") == "INVALID_REQUEST"
