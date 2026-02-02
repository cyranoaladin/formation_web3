import { Cpu, ShieldCheck, Wifi, ArrowLeft } from "lucide-react";

export default function TerminalLayout({ children, mode, statusPulse, onBack }) {
  return (
    <div className="terminal-shell">
      <header className="terminal-header">
        <div className="brand">
          <ShieldCheck size={18} />
          <span>MFAI :: Zyno</span>
        </div>
        <div className="wallet">
          <button className="ghost" type="button">
            Connect Wallet
          </button>
        </div>
      </header>

      <div className="terminal-body">
        <aside className="status-panel">
          <div className="panel-title">System Status</div>
          <div className="status-item">
            <Wifi size={16} />
            <span>Network: Solana Local</span>
          </div>
          <div className="status-item">
            <Cpu size={16} />
            <span>Zyno Core: 99.2%</span>
          </div>
          <div className="status-stream">
            {statusPulse.map((item) => (
              <div key={item} className="pulse-line">
                {item}
              </div>
            ))}
          </div>
          {mode === "LAB" && (
            <button className="ghost back" type="button" onClick={onBack}>
              <ArrowLeft size={16} />
              Return to Grid
            </button>
          )}
        </aside>

        <main className="terminal-main">{children}</main>
      </div>
    </div>
  );
}
