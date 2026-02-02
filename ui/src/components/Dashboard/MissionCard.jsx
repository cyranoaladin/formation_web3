const statusLabel = {
  completed: "COMPLETED",
  active: "ACTIVE",
  locked: "LOCKED",
};

export default function MissionCard({ lab, onSelect }) {
  return (
    <button
      className={`mission-card ${lab.status}`}
      type="button"
      onClick={onSelect}
    >
      <div className="mission-line">
        <span className="mission-id">{lab.id}</span>
        <span className="mission-status">
          {statusLabel[lab.status] || "ACTIVE"}
        </span>
        <span className="mission-difficulty">{lab.difficulty}</span>
      </div>
      <div className="mission-title">{lab.title}</div>
      <div className="mission-meta">ID | STATUS | DIFFICULTY</div>
    </button>
  );
}
