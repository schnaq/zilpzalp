import React from "react";
import { Icon } from "./Icon.jsx";

const TONES = {
  primary: ["var(--color-primary)", "var(--color-primary-shadow)", "var(--white)"],
  accent: ["var(--color-accent)", "var(--color-accent-shadow)", "var(--white)"],
  clay: ["var(--color-info)", "var(--clay-700)", "var(--white)"],
  quiet: ["var(--white)", "var(--sand-300)", "var(--text-strong)"],
};

export function IconButton({ icon, label, tone = "quiet", size = 96, onClick, disabled, style, ...rest }) {
  const [bg, ledge, fg] = TONES[tone] || TONES.quiet;
  const [down, setDown] = React.useState(false);
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      disabled={disabled}
      onClick={onClick}
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      style={{
        display: "inline-flex", alignItems: "center", justifyContent: "center",
        width: size, height: size, flex: "0 0 auto",
        background: bg, color: fg,
        border: tone === "quiet" ? "var(--border-width) solid var(--border-strong)" : "none",
        borderRadius: "var(--radius-pill)",
        boxShadow: disabled ? "none" : `0 ${down ? "2px" : "7px"} 0 ${ledge}`,
        transform: down ? "translateY(5px)" : "translateY(0)",
        transition: "transform var(--dur-instant) var(--ease-out), box-shadow var(--dur-instant) var(--ease-out)",
        opacity: disabled ? 0.45 : 1,
        cursor: disabled ? "default" : "pointer",
        WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      <Icon name={icon} size={Math.round(size * 0.45)} />
    </button>
  );
}
