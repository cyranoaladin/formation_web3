const API_BASE = import.meta.env.VITE_API_BASE || "http://localhost:8000";

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, options);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `HTTP ${res.status}`);
  }
  return res.json();
}

export async function fetchLabs() {
  return request("/labs");
}

export async function uploadSubmission({ labId, file, studentId = "student_demo" }) {
  const form = new FormData();
  form.append("student_id", studentId);
  form.append("lab_id", labId);
  form.append("file", file);

  return request("/submissions/upload_zip", {
    method: "POST",
    body: form,
  });
}

export async function fetchSubmission(submissionId) {
  return request(`/submissions/${submissionId}`);
}

export async function chatWithZyno({ query, contextLabId }) {
  return request("/rag/query", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query,
      context_lab_id: contextLabId,
    }),
  });
}

export async function fetchPendingSubmissions() {
  return request("/mentor/pending");
}

export async function reviewSubmission(submissionId, decision, feedback) {
  return request(`/mentor/verify/${submissionId}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ decision, feedback }),
  });
}

export async function fetchRun(runId) {
  return request(`/runs/${runId}`);
}


