#!/usr/bin/env python3
import json
import os
import sys
import time
import subprocess
from typing import Any

import requests
from pymongo import MongoClient

API_URL = os.getenv("RBK_API_URL", "http://localhost:8000")
LAB_ID = "hello-proof"
ZIP_PATH = os.path.join("tests", "fixtures", "minimal.zip")
DB_URI = os.getenv("RBK_MONGODB_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("RBK_MONGODB_DB", "rbk_labs")


def log(msg: str) -> None:
    print(f"[certify] {msg}", flush=True)


def run(cmd: list[str]) -> None:
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if res.returncode != 0:
        print(res.stdout)
        raise RuntimeError(f"command failed: {' '.join(cmd)}")


def wait_health(timeout_s: int = 120) -> None:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            r = requests.get(f"{API_URL}/health", timeout=2)
            if r.status_code == 200:
                return
        except Exception:
            pass
        time.sleep(2)
    raise RuntimeError("API health check failed")


def get_json(url: str) -> dict[str, Any]:
    r = requests.get(url, timeout=5)
    r.raise_for_status()
    return r.json()


def main() -> int:
    log("start stack")
    run(["docker", "compose", "up", "-d"])

    log("healthcheck")
    wait_health()

    log("lab discovery")
    labs = get_json(f"{API_URL}/labs").get("labs", [])
    lab_match = [l for l in labs if l.get("lab_id") == LAB_ID]
    if not lab_match:
        raise RuntimeError("hello-proof not listed in /labs")
    if lab_match[0].get("status") != "active":
        raise RuntimeError("hello-proof not active")

    if not os.path.isfile(ZIP_PATH):
        raise RuntimeError(f"missing zip fixture: {ZIP_PATH}")

    log("upload submission")
    with open(ZIP_PATH, "rb") as f:
        files = {"file": (os.path.basename(ZIP_PATH), f, "application/zip")}
        data = {"student_id": "stu_certify", "lab_id": LAB_ID}
        r = requests.post(f"{API_URL}/submissions/upload_zip", data=data, files=files, timeout=10)
        r.raise_for_status()
        resp = r.json()

    submission_id = resp.get("submission_id")
    status = resp.get("status")
    if not submission_id or status != "queued":
        raise RuntimeError("upload response invalid")

    log("poll submission status")
    seen_running = False
    proof_id = None
    final_status = None
    for _ in range(240):
        s = get_json(f"{API_URL}/submissions/{submission_id}")
        final_status = s.get("status", "")
        if final_status == "running":
            seen_running = True
        if final_status not in ("queued", "running", "uploaded"):
            proof_id = s.get("proof_bundle_id")
            break
        time.sleep(1)

    if final_status is None:
        raise RuntimeError("submission poll failed")
    if final_status not in ("completed", "failed", "needs_review"):
        raise RuntimeError(f"unexpected status: {final_status}")
    if not seen_running:
        raise RuntimeError("status never transitioned to running")
    if final_status != "completed":
        raise RuntimeError(f"submission did not complete: {final_status}")
    if not proof_id:
        raise RuntimeError("missing proof_bundle_id")

    log("proof verification")
    proof = get_json(f"{API_URL}/proofs/{proof_id}")
    if proof.get("decision_hint") != "validated":
        raise RuntimeError("decision_hint invalid")
    if "score" not in proof or "auto" not in proof.get("score", {}):
        raise RuntimeError("score.auto missing")
    artifacts = proof.get("artifacts", {})
    if "logs" not in artifacts:
        raise RuntimeError("logs missing in proof artifacts")

    log("persistence check")
    client = MongoClient(DB_URI)
    db = client[DB_NAME]
    count = db.proof_bundles.count_documents({"proof_bundle_id": proof_id})
    if count < 1:
        raise RuntimeError("proof not persisted in Mongo")

    print("[CERTIFIED] SYSTEM READY FOR PRODUCTION LAUNCH")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[CERTIFY-FAIL] {exc}")
        raise
