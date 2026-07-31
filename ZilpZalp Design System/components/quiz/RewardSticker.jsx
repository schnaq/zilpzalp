import React from "react";
import { Icon } from "../core/Icon.jsx";

const TONES = {
  sun: ["var(--sun-300)", "var(--sun-600)", "var(--bark-700)"],
  leaf: ["var(--olive-200)", "var(--olive-600)", "var(--olive-800)"],
  hoopoe: ["var(--orange-200)", "var(--orange-600)", "var(--orange-700)"],
  rare: ["var(--berry-300)", "var(--berry-700)", "var(--white)"],
};

/* Earned collectible. Locked stickers stay visible but greyed — kids need to see what's next. */
export function RewardSticker({ icon = "star", photo, credit, label, tone = "sun", locked, size = 140, style, ...rest }) {
  const [bg, edge, fg] = TONES[tone] || TONES.sun;
  return (
    <div style={{ display: "inline-flex", flexDirection: "column", alignItems: "center", gap: "var(--space-2)", ...style }} {...rest}>
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "center",
        width: size, height: size, borderRadius: "var(--radius-pill)",
        background: locked ? "var(--sand-200)" : bg,
        border: `var(--border-width-thick) solid ${locked ? "var(--sand-300)" : edge}`,
        color: locked ? "var(--ink-300)" : fg,
        boxShadow: locked ? "none" : "var(--shadow-md)",
        transform: locked ? "none" : "rotate(-4deg)",
        overflow: "hidden", position: "relative",
      }}>
        {photo && !locked ? (
          <>
            <img src={photo} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
            {credit ? (
              <span style={{
                position: "absolute", left: 0, right: 0, bottom: 0, padding: "12px 8px 5px", textAlign: "center",
                background: "linear-gradient(to top, rgba(42,34,19,.55), rgba(42,34,19,0))",
                font: "var(--weight-semibold) 11px/1.2 var(--font-body)", color: "var(--cream-50)",
              }}>{credit}</span>
            ) : null}
          </>
        ) : (
          <Icon name={locked ? "lock" : icon} size={Math.round(size * 0.45)} strokeWidth={2.5} />
        )}
      </div>
      {label ? (
        <span style={{
          font: "var(--weight-bold) var(--text-body)/1.2 var(--font-display)",
          color: locked ? "var(--text-muted)" : "var(--text-strong)", textAlign: "center", maxWidth: size + 40,
        }}>{label}</span>
      ) : null}
    </div>
  );
}
