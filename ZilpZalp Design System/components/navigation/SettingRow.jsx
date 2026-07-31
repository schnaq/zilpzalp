import React from "react";
import { Icon } from "../core/Icon.jsx";

/* Grown-ups area only — the one place with small type and switches. */
export function SettingRow({ icon, label, hint, value, on, onToggle, style, ...rest }) {
  const isSwitch = typeof on === "boolean";
  return (
    <div
      style={{
        display: "flex", alignItems: "center", gap: "var(--space-4)",
        padding: "var(--space-4) var(--space-5)",
        background: "var(--surface-card)",
        borderBottom: "2px solid var(--border-card)",
        font: "var(--weight-semibold) var(--text-body)/var(--lh-body) var(--font-body)",
        color: "var(--text-body)", ...style,
      }}
      {...rest}
    >
      {icon ? <Icon name={icon} size={28} color="var(--olive-600)" /> : null}
      <div style={{ flex: 1 }}>
        <div style={{ color: "var(--text-strong)", fontWeight: "var(--weight-bold)" }}>{label}</div>
        {hint ? <div style={{ fontSize: "var(--text-caption)", color: "var(--text-muted)", marginTop: 2 }}>{hint}</div> : null}
      </div>
      {isSwitch ? (
        <button
          type="button" role="switch" aria-checked={on} aria-label={label} onClick={onToggle}
          style={{
            width: 72, height: 40, padding: 4, border: "none", cursor: "pointer",
            borderRadius: "var(--radius-pill)",
            background: on ? "var(--color-primary)" : "var(--sand-300)",
            transition: "background var(--dur-fast) var(--ease-out)",
          }}
        >
          <span style={{
            display: "block", width: 32, height: 32, borderRadius: "var(--radius-pill)",
            background: "var(--white)", boxShadow: "var(--shadow-sm)",
            transform: on ? "translateX(32px)" : "translateX(0)",
            transition: "transform var(--dur-fast) var(--ease-bounce)",
          }} />
        </button>
      ) : (
        <span style={{ color: "var(--text-muted)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
          {value}<Icon name="chevron-right" size={22} />
        </span>
      )}
    </div>
  );
}
