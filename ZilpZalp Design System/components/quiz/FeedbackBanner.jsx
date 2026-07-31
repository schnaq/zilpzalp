import React from "react";
import { Icon } from "../core/Icon.jsx";

const TONES = {
  correct: ["var(--color-correct-soft)", "var(--color-correct)", "var(--olive-800)", "party-popper"],
  retry: ["var(--color-retry-soft)", "var(--color-retry)", "var(--bark-700)", "hand-heart"],
  hint: ["var(--clay-50)", "var(--clay-300)", "var(--clay-700)", "lightbulb"],
};

export function FeedbackBanner({ children, tone = "correct", icon, style, ...rest }) {
  const [bg, edge, fg, defIcon] = TONES[tone] || TONES.correct;
  return (
    <div
      role="status"
      style={{
        display: "flex", alignItems: "center", gap: "var(--space-4)",
        padding: "var(--space-4) var(--space-6)",
        background: bg, border: `var(--border-width) solid ${edge}`,
        borderRadius: "var(--radius-pill)", color: fg,
        font: "var(--weight-bold) var(--text-headline)/1.2 var(--font-display)",
        boxShadow: "var(--shadow-sm)",
        animation: "zz-pop var(--dur-slow) var(--ease-bounce) both",
        ...style,
      }}
      {...rest}
    >
      <Icon name={icon || defIcon} size={38} />
      <span>{children}</span>
    </div>
  );
}
