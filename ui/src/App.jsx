import { useEffect, useMemo, useState } from "react";
import TerminalLayout from "./components/Layout/TerminalLayout.jsx";
import Console from "./components/Terminal/Console.jsx";
import MissionCard from "./components/Dashboard/MissionCard.jsx";
import CodeUploader from "./components/Editor/CodeUploader.jsx";
import { fetchLabs } from "./services/api.js";

import MentorDashboard from "./components/Mentor/MentorDashboard.jsx";

const MODES = {
  BOOT: "BOOT",
  DASHBOARD: "DASHBOARD",
  LAB: "LAB",
  MENTOR: "MENTOR"
};

const statusMap = {
  "security-01-missing-owner": "completed",
  "security-02-unverified-pda": "active",
  "security-03-signer-authorization": "locked",
};

const fallbackLabs = [
  {
    id: "security-01-missing-owner",
    title: "Security N1: Missing Owner Check",
    difficulty: "N1",
  },
  {
    id: "security-02-unverified-pda",
    title: "Security N1: Unverified PDA",
    difficulty: "N1",
  },
  {
    id: "security-03-signer-authorization",
    title: "Security N1: Signer vs Authority",
    difficulty: "N1",
  },
];

export default function App() {
  const [mode, setMode] = useState(MODES.BOOT);
  const [labs, setLabs] = useState(fallbackLabs);
  const [selectedLab, setSelectedLab] = useState(fallbackLabs[1]);

  useEffect(() => {
    const loadLabs = async () => {
      try {
        const res = await fetchLabs();
        const apiLabs = (res.labs || []).map((lab) => ({
          id: lab.lab_id,
          title: lab.title,
          difficulty: "N1",
        }));
        if (apiLabs.length) {
          setLabs(apiLabs);
          setSelectedLab(apiLabs[1] || apiLabs[0]);
        }
      } catch {
        setLabs(fallbackLabs);
      }
    };
    loadLabs();
  }, []);

  const statusPulse = useMemo(
    () => ["SOL-LOCAL", "CPU: 42%", "SYNC: OK", "ZK: ARMING"],
    []
  );

  const labsWithStatus = labs.map((lab) => ({
    ...lab,
    status: statusMap[lab.id] || "active",
  }));

  const renderMain = () => {
    if (mode === MODES.BOOT) {
      return (
        <div className="boot-screen">
          <div className="boot-title">Zyno Terminal</div>
          <div className="boot-sub">Initializing MFAI Secure Ops...</div>
          <button className="boot-cta" onClick={() => setMode(MODES.DASHBOARD)}>
            Enter Mission Grid
          </button>

          <div style={{ marginTop: "2rem", opacity: 0.3 }}>
            <button onClick={() => setMode(MODES.MENTOR)} style={{ background: "none", border: "none", color: "inherit", cursor: "pointer", fontSize: "0.8rem", textDecoration: "underline" }}>
              [MENTOR ACCESS]
            </button>
          </div>
        </div>
      );
    }

    if (mode === MODES.MENTOR) {
      return <MentorDashboard onBack={() => setMode(MODES.BOOT)} />;
    }

    if (mode === MODES.DASHBOARD) {
      return (
        <div className="dashboard">
          <div className="dashboard-header">
            <div className="eyebrow">Mission Grid</div>
            <div className="dashboard-title">Security N1 Track</div>
            <p className="dashboard-copy">
              Select a mission to initialize. Active mission syncs with the
              Zyno console.
            </p>
          </div>
          <div className="mission-grid">
            {labsWithStatus.map((lab) => (
              <MissionCard
                key={lab.id}
                lab={lab}
                onSelect={() => {
                  setSelectedLab(lab);
                  if (lab.status !== "locked") {
                    setMode(MODES.LAB);
                  }
                }}
              />
            ))}
          </div>
        </div>
      );
    }

    return (
      <div className="lab-view">
        <div className="lab-header">
          <div className="eyebrow">Active Mission</div>
          <div className="lab-title">{selectedLab.title}</div>
          <div className="lab-meta">Status: {selectedLab.status}</div>
        </div>
        <div className="lab-content">
          <Console
            title="Zyno :: Mission Console"
            lines={[
              "Bootstrapping secure channel...",
              "Analyzing lab context...",
              "Awaiting student patch submission.",
            ]}
            contextLabId={selectedLab.id}
          />
          <CodeUploader labId={selectedLab.id} />
        </div>
      </div>
    );
  };

  return (
    <TerminalLayout
      mode={mode}
      statusPulse={statusPulse}
      onBack={() => setMode(MODES.DASHBOARD)}
    >
      {renderMain()}
    </TerminalLayout>
  );
}

