import { useEffect, useState } from "react";
import { fetchPendingSubmissions, reviewSubmission } from "../../services/api";

export default function MentorDashboard({ onBack }) {
    const [submissions, setSubmissions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const loadPending = async () => {
        setLoading(true);
        try {
            const data = await fetchPendingSubmissions();
            setSubmissions(data);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadPending();
    }, []);

    const handleReview = async (id, decision) => {
        try {
            await reviewSubmission(id, decision, "Manual review by mentor");
            await loadPending(); // Reload list
        } catch (err) {
            alert("Error reviewing: " + err.message);
        }
    };

    return (
        <div className="mentor-dashboard" style={{ padding: "2rem", color: "#fff", background: "#0a0a0a", minHeight: "100vh" }}>
            <header style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "2rem" }}>
                <h1 style={{ margin: 0, fontFamily: "monospace", color: "#00ff9d" }}>MENTOR // OPS</h1>
                <button onClick={onBack} style={{ background: "transparent", border: "1px solid #333", color: "#666", padding: "0.5rem 1rem", cursor: "pointer" }}>
                    EXIT
                </button>
            </header>

            {loading && <div>Loading pending tasks...</div>}
            {error && <div style={{ color: "red" }}>Error: {error}</div>}

            {!loading && submissions.length === 0 && (
                <div style={{ textAlign: "center", color: "#666", marginTop: "4rem" }}>
                    NO PENDING SUBMISSIONS
                </div>
            )}

            <div className="submissions-grid" style={{ display: "grid", gap: "1rem" }}>
                {submissions.map((sub) => (
                    <div key={sub.submission_id} style={{ border: "1px solid #333", padding: "1rem", borderRadius: "4px", background: "#111" }}>
                        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "1rem" }}>
                            <span style={{ color: "#888", fontSize: "0.8rem" }}>{sub.submission_id}</span>
                            <span style={{ color: "#00ff9d", fontSize: "0.8rem" }}>{new Date(sub.created_at).toLocaleString()}</span>
                        </div>
                        <div style={{ fontSize: "1.2rem", marginBottom: "0.5rem" }}>
                            Student: <span style={{ color: "#fff" }}>{sub.student_id}</span>
                        </div>
                        <div style={{ marginBottom: "1rem" }}>
                            Lab: <span style={{ color: "#ccc" }}>{sub.lab_id}</span>
                        </div>

                        <div style={{ display: "flex", gap: "1rem" }}>
                            <button
                                onClick={() => handleReview(sub.submission_id, "approved")}
                                style={{ flex: 1, padding: "0.5rem", background: "#003300", border: "1px solid #00ff00", color: "#00ff00", cursor: "pointer" }}
                            >
                                APPROVE
                            </button>
                            <button
                                onClick={() => handleReview(sub.submission_id, "rejected")}
                                style={{ flex: 1, padding: "0.5rem", background: "#330000", border: "1px solid #ff0000", color: "#ff0000", cursor: "pointer" }}
                            >
                                REJECT
                            </button>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}
