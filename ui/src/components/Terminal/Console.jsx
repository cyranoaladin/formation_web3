import { useEffect, useRef, useState } from "react";
import { chatWithZyno } from "../../services/api.js";

export default function Console({ title, lines, contextLabId }) {
  const [entries, setEntries] = useState(
    (lines || []).map((text) => ({ role: "system", text }))
  );
  const [input, setInput] = useState("");
  const [thinking, setThinking] = useState(false);
  const endRef = useRef(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [entries, thinking]);

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (!input.trim() || thinking) return;

    const question = input.trim();
    setInput("");
    setEntries((prev) => [...prev, { role: "user", text: question }]);
    setThinking(true);

    try {
      const res = await chatWithZyno({ query: question, contextLabId });
      const responseLine = res.system_prompt
        ? res.system_prompt.slice(0, 280) + "..."
        : "Signal received. No context returned.";
      setEntries((prev) => [...prev, { role: "zyno", text: responseLine }]);
    } catch (err) {
      setEntries((prev) => [
        ...prev,
        { role: "zyno", text: `ERROR: ${err.message || "Neural link failed"}` },
      ]);
    } finally {
      setThinking(false);
    }
  };

  return (
    <div className="console">
      <div className="console-header">{title}</div>
      <div className="console-body">
        {entries.map((entry, index) => {
          if (entry.role === "user") {
            return (
              <div key={`${entry.text}-${index}`} className="console-line user">
                <span className="console-prefix">
                  root@zyno:~$ 
                </span>
                <span>{entry.text}</span>
              </div>
            );
          }
          if (entry.role === "zyno") {
            return (
              <div key={`${entry.text}-${index}`} className="console-line zyno">
                <span className="console-prefix">&gt; </span>
                <span>{entry.text}</span>
              </div>
            );
          }
          return (
            <div key={`${entry.text}-${index}`} className="console-line system">
              <span>{entry.text}</span>
            </div>
          );
        })}
        {thinking && (
          <div className="console-line system">&gt; AWAITING RESPONSE...</div>
        )}
        <div ref={endRef} />
      </div>
      <form className="console-input" onSubmit={handleSubmit}>
        <span className="prompt">root@zyno:~$</span>
        <input
          value={input}
          onChange={(event) => setInput(event.target.value)}
          placeholder="Type command..."
        />
        <span className="cursor" aria-hidden="true" />
      </form>
    </div>
  );
}
