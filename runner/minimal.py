#!/usr/bin/env python3
from __future__ import annotations
import json, os, shutil, subprocess, sys, zipfile
from datetime import datetime
from pathlib import Path

ISO = lambda: datetime.utcnow().replace(microsecond=0).isoformat()+"Z"

def ensure_dir(d: Path) -> None:
    d.mkdir(parents=True, exist_ok=True)

def unzip_to(zip_path: Path, dest: Path) -> None:
    ensure_dir(dest)
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(dest)

def execute_lab(lab_id: str, submission_id: str, zip_path: Path, sandbox: Path) -> dict:
    # Prepare sandbox
    if sandbox.exists():
        shutil.rmtree(sandbox)
    work = sandbox / 'work'
    out = sandbox / 'out'
    ensure_dir(work); ensure_dir(out)
    unzip_to(zip_path, work)

    # Determine command from spec if present; else built-in hello-proof
    spec_path = Path('labs/specs')/lab_id/'lab.json'
    cmd = None
    if spec_path.exists():
        try:
            spec=json.loads(spec_path.read_text(encoding='utf-8'))
            cmd=spec.get('command')
        except Exception:
            cmd=None
    if not cmd:
        cmd = "sh -lc 'echo hello-proof; echo sandbox=${PWD}'"

    # Run command and capture
    started=ISO()
    proc = subprocess.run(cmd, shell=True, cwd=str(work), capture_output=True, text=True)
    finished=ISO()

    logs = "$ " + cmd + "\n" + (proc.stdout or "")
    if proc.stderr:
        logs += "\n[stderr]\n" + proc.stderr
    (out / 'logs.txt').write_text(logs, encoding='utf-8')

    result = {
        'status': 'ok' if proc.returncode==0 else 'failed',
        'lab_id': lab_id,
        'submission_id': submission_id,
        'started_at': started,
        'finished_at': finished,
        'returncode': proc.returncode,
    }
    (out / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    return {'out_dir': str(out), 'work_dir': str(work), 'result': result}

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--lab-id', required=True)
    ap.add_argument('--submission-id', required=True)
    ap.add_argument('--zip', required=True)
    ap.add_argument('--sandbox', required=True)
    a=ap.parse_args()
    info = execute_lab(a.lab_id, a.submission_id, Path(a.zip), Path(a.sandbox))
    print(json.dumps({'ok': True, **info}, ensure_ascii=False))
