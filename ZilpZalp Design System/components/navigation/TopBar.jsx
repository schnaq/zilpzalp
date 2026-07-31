import React from "react";
import { IconButton } from "../core/IconButton.jsx";

/* Fixed iPad header: back at left, wordless progress centred, grown-up door at right. */
export function TopBar({ onBack, onSettings, center, title, style, ...rest }) {
  return (
    <header
      style={{
        display: "flex", alignItems: "center", gap: "var(--space-5)",
        padding: "var(--space-4) var(--gutter-screen)",
        background: "color-mix(in oklab, var(--cream-50) 90%, transparent)",
        backdropFilter: "blur(12px)",
        borderBottom: "var(--border-width) solid var(--border-card)",
        ...style,
      }}
      {...rest}
    >
      {onBack ? <IconButton icon="chevron-left" label="Zurück" size={72} onClick={onBack} /> : <span style={{ width: 72 }} />}
      <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", gap: "var(--space-4)" }}>
        {title ? (
          <span style={{ font: "var(--weight-bold) var(--text-headline)/1 var(--font-display)", color: "var(--text-strong)" }}>{title}</span>
        ) : null}
        {center}
      </div>
      {onSettings ? <IconButton icon="user-round-cog" label="Für Erwachsene" size={72} onClick={onSettings} /> : <span style={{ width: 72 }} />}
    </header>
  );
}
