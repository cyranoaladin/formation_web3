import { useCallback, useEffect, useRef, useState } from "react";
import { fetchSubmission, uploadSubmission } from "../../services/api.js";

export default function CodeUploader({ labId }) {
  const [dragging, setDragging] = useState(false);
  const [logLines, setLogLines] = useState([
    "> INITIALIZING UPLINK...",
    "> AWAITING WORKER...",
  ]);
  const [submissionId, setSubmissionId] = useState(null);
  const [status, setStatus] = useState(null);
  const logRef = useRef(null);

  useEffect(() => {
    if (!logRef.current) return;
    logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [logLines]);

  const onUpload = async (file) => {
    if (!file) return;
    setLogLines([`> UPLOADING ${file.name}...`]);
    try {
      const res = await uploadSubmission({ labId, file });
      setSubmissionId(res.submission_id);
      setStatus(res.status);
      setLogLines((prev) => [
        ...prev,
        `> SUBMISSION ${res.submission_id} QUEUED.`,
        "> AWAITING WORKER...",
      ]);
    } catch (err) {
      setLogLines((prev) => [
        ...prev,
        `> UPLOAD FAILED: ${err.message || "unknown"}`,
      ]);
    }
  };

  const handleDrop = useCallback(
    (event) => {
      event.preventDefault();
      setDragging(false);
      const file = event.dataTransfer.files?.[0];
      if (file) {
        onUpload(file);
      }
    },
    [labId]
  );

  useEffect(() => {
    if (!submissionId) return;

    const interval = setInterval(async () => {
      try {
        const res = await fetchSubmission(submissionId);
        setStatus(res.status);

        let newLogs = [`> STATUS: ${res.status.toUpperCase()}`];

        if (res.latest_run_id) {
          try {
            // Dynamic import to avoid circular dep if needed, or just use imported
            const { fetchRun } = await import("../../services/api.js");
            const runData = await fetchRun(res.latest_run_id);
            if (runData && runData.runner && runData.runner.logs) {
              // We found logs!
              // Let's just append the last few lines or full logs?
              // For now, let's show a snippet
              const logs = runData.runner.logs;
              if (logs) {
                newLogs.push("--- RUNNER LOGS START ---");
                // simple split
                const lines = logs.split("\n");
                // take last 5 lines if too long?
                if (lines.length > 20) {
                  newLogs.push(...lines.slice(-20));
                } else {
                  newLogs.push(...lines);
                }
                newLogs.push("--- RUNNER LOGS END ---");
              }
            }
          } catch (e) {
            // ignore run fetch error
          }
        }

        setLogLines((prev) => {
          // Avoid spamming duplicate status lines, but logs might change
          // Simplified: just update if status changed or just heartbeat
          const last = prev[prev.length - 1];
          if (last !== newLogs[0] || newLogs.length > 1) {
            // If we have logs, maybe we want to replace the view or append?
            // Appending poll logs is messy.
            // Strategy: If completed/failed, show logs once.
            if (res.status === 'completed' || res.status === 'failed' || res.status === 'needs_review') {
              // Return combined logs
              return [...prev.filter(l => !l.startsWith("---")), ...newLogs];
            }
            return [...prev, newLogs[0]];
          }
          return prev;
        });

        // specific check for completion
        if (["completed", "failed", "needs_review"].includes(res.status)) {
          clearInterval(interval);
        }

      } catch (err) {
        setLogLines((prev) => [
          ...prev,
          `> POLLING FAILED: ${err.message || "unknown"}`,
        ]);
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [submissionId]);

  return (
    <div
      className={`uploader ${dragging ? "dragging" : ""}`}
      onDragOver={(event) => {
        event.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={handleDrop}
    >
      <div className="uploader-title">UPLOAD LAB PATCH</div>
      <div className="uploader-sub">Drag & drop ZIP or click to browse.</div>
      <label className="uploader-action">
        <input
          type="file"
          accept=".zip"
          onChange={(event) => onUpload(event.target.files?.[0])}
        />
        SELECT ZIP
      </label>
      <pre ref={logRef} className="uploader-log">
        {logLines.join("\n")}
      </pre>
      {status && <div className="uploader-status">{status}</div>}
    </div>
  );
}
