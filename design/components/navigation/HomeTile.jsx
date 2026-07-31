import React from "react";
import { Icon } from "../core/Icon.jsx";

const TONES = {
  leaf: ["var(--olive-100)", "var(--color-primary)", "var(--olive-700)"],
  clay: ["var(--clay-100)", "var(--color-info)", "var(--clay-700)"],
  sun: ["var(--sun-200)", "var(--sun-400)", "var(--sun-600)"],
  hoopoe: ["var(--orange-100)", "var(--color-accent)", "var(--orange-700)"],
};

/* A nest on the home tree: one activity. Locked nests show an egg, not a padlock wall. */
export function HomeTile({ icon = "bird", label, tone = "leaf", stars = 0, locked, size = 240, onOpen, style, ...rest }) {
  const [bg, edge, fg] = TONES[tone] || TONES.leaf;
  const [down, setDown] = React.useState(false);
  return (
    <button
      type="button"
      aria-label={label}
      onClick={locked ? undefined : onOpen}
      onPointerDown={() => !locked && setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      style={{
        display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
        gap: "var(--space-3)", width: size, height: size, padding: "var(--space-4)",
        background: locked ? "var(--sand-200)" : bg,
        border: `var(--border-width-thick) solid ${locked ? "var(--sand-300)" : edge}`,
        borderRadius: "var(--radius-tile)",
        color: locked ? "var(--ink-300)" : fg,
        boxShadow: locked ? "none" : `0 ${down ? "3px" : "10px"} 0 ${edge}`,
        transform: down ? "translateY(7px)" : "translateY(0)",
        transition: "transform var(--dur-instant) var(--ease-out), box-shadow var(--dur-instant) var(--ease-out)",
        cursor: locked ? "default" : "pointer", WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      <Icon name={locked ? "egg" : icon} size={Math.round(size * 0.34)} strokeWidth={2.5} />
      {label ? <span style={{ font: "var(--weight-bold) var(--text-label)/1.1 var(--font-display)", textAlign: "center" }}>{label}</span> : null}
      {!locked && stars ? (
        <span style={{ display: "flex", gap: 4 }}>
          {Array.from({ length: 3 }, (_, i) => (
            <Icon key={i} name="star" size={24} color={i < stars ? "var(--sun-500)" : "var(--sand-400)"} strokeWidth={3} />
          ))}
        </span>
      ) : null}
    </button>
  );
}
