import React, { useMemo, useState } from "react";

const API_BASE = (import.meta.env.VITE_API_BASE ?? "http://localhost:8000").replace(/\/+$/, "");

async function apiGet(path) {
  const r = await fetch(`${API_BASE}${path}`, { method: "GET" });
  const text = await r.text();
  if (!r.ok) throw new Error(`GET ${path} -> ${r.status} ${text}`);
  return JSON.parse(text);
}

async function apiUploadZip({ student_id, lab_id, file }) {
  const fd = new FormData();
  fd.append("student_id", student_id);
  fd.append("lab_id", lab_id);
  fd.append("file", file);
  const r = await fetch(`${API_BASE}/submissions/upload_zip`, { method: "POST", body: fd });
  const text = await r.text();
  if (!r.ok) throw new Error(`UPLOAD -> ${r.status} ${text}`);
  return JSON.parse(text);
}

function prettyJson(obj) {
  try {
    return JSON.stringify(obj, null, 2);
  } catch {
    return String(obj);
  }
}

export default function App() {
  const [studentId, setStudentId] = useState("stu_ui");
  const [labId, setLabId] = useState("lab_demo");
  const [file, setFile] = useState(null);

  const [submissionId, setSubmissionId] = useState("");
  const [runId, setRunId] = useState("");

  const [busy, setBusy] = useState(false);
  const [out, setOut] = useState("");

  const canUpload = useMemo(() => Boolean(studentId && labId && file), [studentId, labId, file]);

  async function onHealth() {
    setBusy(true);
    setOut("");
    try {
      const j = await apiGet("/health");
      setOut(prettyJson(j));
    } catch (e) {
      setOut(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function onUpload() {
    setBusy(true);
    setOut("");
    try {
      const j = await apiUploadZip({ student_id: studentId, lab_id: labId, file });
      setSubmissionId(j.submission_id || "");
      setOut(prettyJson(j));
    } catch (e) {
      setOut(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function onFetchSubmission() {
    if (!submissionId) return;
    setBusy(true);
    setOut("");
    try {
      const j = await apiGet(`/submissions/${submissionId}`);
      setRunId(j.latest_run_id || "");
      setOut(prettyJson(j));
    } catch (e) {
      setOut(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function onFetchRun() {
    if (!runId) return;
    setBusy(true);
    setOut("");
    try {
      const j = await apiGet(`/runs/${runId}`);
      setOut(prettyJson(j));
    } catch (e) {
      setOut(String(e));
    } finally {
      setBusy(false);
    }
  }


  async function onLabs() {
    setBusy(true);
    setOut("");
    try {
      const j = await apiGet("/labs");
      setOut(prettyJson(j));
    } catch (e) {
      setOut(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ fontFamily: "ui-sans-serif, system-ui", padding: 16, maxWidth: 960, margin: "0 auto" }}>
      <h1 style={{ margin: "8px 0 4px" }}>RBK Labs</h1>
      <div style={{ opacity: 0.8, marginBottom: 16 }}>Upload ZIP → Worker run → Proof bundle (needs_review)</div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
        <div style={{ border: "1px solid #ddd", borderRadius: 12, padding: 12 }}>
          <div style={{ fontWeight: 600, marginBottom: 8 }}>API</div>
          <button disabled={busy} onClick={onHealth} style={{ padding: "8px 10px" }}>Health</button>
          <div style={{ marginTop: 10, fontSize: 12, opacity: 0.8 }}>API_BASE: {API_BASE}</div>
        </div>

        <div style={{ border: "1px solid #ddd", borderRadius: 12, padding: 12 }}>
          <div style={{ fontWeight: 600, marginBottom: 8 }}>Upload submission (.zip)</div>
          <div style={{ display: "grid", gap: 8 }}>
            <label style={{ display: "grid", gap: 4 }}>
              <span>student_id</span>
              <input value={studentId} onChange={(e) => setStudentId(e.target.value)} style={{ padding: 8 }} />
            </label>
            <label style={{ display: "grid", gap: 4 }}>
              <span>lab_id</span>
              <input value={labId} onChange={(e) => setLabId(e.target.value)} style={{ padding: 8 }} />
            </label>
            <label style={{ display: "grid", gap: 4 }}>
              <span>zip file</span>
              <input type="file" accept=".zip" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
            </label>

            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              <button disabled={!canUpload || busy} onClick={onUpload} style={{ padding: "8px 10px" }}>Upload</button>
              <button disabled={!submissionId || busy} onClick={onFetchSubmission} style={{ padding: "8px 10px" }}>Get submission</button>
              <button disabled={!runId || busy} onClick={onFetchRun} style={{ padding: "8px 10px" }}>Get run</button>
            </div>

            <div style={{ fontSize: 12, opacity: 0.85 }}>
              submission_id: <b>{submissionId || "-"}</b><br />
              latest_run_id: <b>{runId || "-"}</b>
            </div>
          </div>
        </div>
      </div>

      <div style={{ marginTop: 12, border: "1px solid #ddd", borderRadius: 12, padding: 12 }}>
        <div style={{ fontWeight: 600, marginBottom: 8 }}>Output</div>
        <pre style={{ margin: 0, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{out}</pre>
      </div>
    </div>
  );
}
