import React from "react";

const TONES = {
  paper: { bg: "var(--surface-card)", border: "var(--border-card)" },
  leaf: { bg: "var(--olive-50)", border: "var(--olive-300)" },
  clay: { bg: "var(--clay-50)", border: "var(--clay-200)" },
  sun: { bg: "var(--sun-100)", border: "var(--sun-300)" },
  sand: { bg: "var(--surface-sunken)", border: "var(--sand-300)" },
};

export function Card({ children, tone = "paper", pad = "var(--space-5)", elevation = "md", style, ...rest }) {
  const t = TONES[tone] || TONES.paper;
  return (
    <div
      style={{
        background: t.bg,
        border: `var(--border-width) solid ${t.border}`,
        borderRadius: "var(--radius-card)",
        boxShadow: elevation === "none" ? "none" : `var(--shadow-${elevation})`,
        padding: pad,
        color: "var(--text-body)",
        font: `var(--weight-semibold) var(--text-body)/var(--lh-body) var(--font-body)`,
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}
