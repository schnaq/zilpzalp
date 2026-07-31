import React from "react";
import { Icon } from "./Icon.jsx";

const TONES = {
  primary: { bg: "var(--color-primary)", press: "var(--color-primary-press)", ledge: "var(--color-primary-shadow)", fg: "var(--text-on-color)" },
  accent:  { bg: "var(--color-accent)",  press: "var(--color-accent-press)",  ledge: "var(--color-accent-shadow)",  fg: "var(--text-on-color)" },
  reward:  { bg: "var(--color-reward)",  press: "var(--sun-500)",             ledge: "var(--color-reward-shadow)",  fg: "var(--text-on-reward)" },
  quiet:   { bg: "var(--white)",         press: "var(--cream-100)",           ledge: "var(--sand-300)",             fg: "var(--text-strong)" },
};
const SIZES = {
  md: { h: "var(--touch-min)", px: "var(--space-5)", fs: "var(--text-label)", icon: 26, ledge: "6px" },
  lg: { h: "var(--touch-comfy)", px: "var(--space-6)", fs: "var(--text-headline)", icon: 34, ledge: "8px" },
  xl: { h: "120px", px: "var(--space-7)", fs: "var(--text-title)", icon: 44, ledge: "10px" },
};

export function Button({ children, tone = "primary", size = "lg", icon, iconRight, block, disabled, onClick, style, ...rest }) {
  const t = TONES[tone] || TONES.primary;
  const s = SIZES[size] || SIZES.lg;
  const [down, setDown] = React.useState(false);
  const [hover, setHover] = React.useState(false);
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => { setDown(false); setHover(false); }}
      onPointerEnter={() => setHover(true)}
      style={{
        display: block ? "flex" : "inline-flex", width: block ? "100%" : "auto",
        alignItems: "center", justifyContent: "center", gap: "var(--space-3)",
        minHeight: s.h, padding: `0 ${s.px}`,
        font: `var(--weight-bold) ${s.fs}/1 var(--font-display)`,
        letterSpacing: "var(--tracking-loose)",
        color: t.fg,
        background: down ? t.press : hover && !disabled ? `color-mix(in oklab, ${t.bg} 88%, white)` : t.bg,
        border: tone === "quiet" ? "var(--border-width) solid var(--border-strong)" : "none",
        borderRadius: "var(--radius-button)",
        boxShadow: disabled ? "none" : `0 ${down ? "2px" : s.ledge} 0 ${t.ledge}`,
        transform: down ? `translateY(${parseInt(s.ledge, 10) - 2}px)` : "translateY(0)",
        transition: "transform var(--dur-instant) var(--ease-out), background var(--dur-fast) var(--ease-out), box-shadow var(--dur-instant) var(--ease-out)",
        opacity: disabled ? 0.45 : 1,
        cursor: disabled ? "default" : "pointer",
        WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      {icon ? <Icon name={icon} size={s.icon} /> : null}
      {children}
      {iconRight ? <Icon name={iconRight} size={s.icon} /> : null}
    </button>
  );
}
