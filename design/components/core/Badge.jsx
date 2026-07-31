import React from "react";
import { Icon } from "./Icon.jsx";

const TONES = {
  leaf: ["var(--color-primary-soft)", "var(--olive-700)"],
  hoopoe: ["var(--color-accent-soft)", "var(--orange-700)"],
  sun: ["var(--sun-200)", "var(--bark-700)"],
  clay: ["var(--clay-100)", "var(--clay-700)"],
  rare: ["var(--berry-100)", "var(--berry-700)"],
  sand: ["var(--sand-200)", "var(--ink-700)"],
};

export function Badge({ children, tone = "leaf", icon, style, ...rest }) {
  const [bg, fg] = TONES[tone] || TONES.leaf;
  return (
    <span
      style={{
        display: "inline-flex", alignItems: "center", gap: "var(--space-2)",
        padding: "8px 18px", background: bg, color: fg,
        borderRadius: "var(--radius-pill)",
        font: "var(--weight-bold) var(--text-body)/1 var(--font-display)",
        letterSpacing: "var(--tracking-loose)", whiteSpace: "nowrap",
        ...style,
      }}
      {...rest}
    >
      {icon ? <Icon name={icon} size={22} /> : null}
      {children}
    </span>
  );
}
