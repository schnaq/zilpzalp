import React from "react";
import { Icon } from "../core/Icon.jsx";

/* Wordless progress: one leaf per question. Filled = answered right. */
export function QuizProgress({ total = 5, done = 0, current = 0, size = 44, style, ...rest }) {
  return (
    <div role="img" aria-label={`${done} von ${total}`} style={{ display: "flex", gap: "var(--space-3)", alignItems: "center", ...style }} {...rest}>
      {Array.from({ length: total }, (_, i) => {
        const filled = i < done;
        const active = i === current;
        return (
          <span key={i} style={{
            display: "flex", alignItems: "center", justifyContent: "center",
            width: size, height: size, borderRadius: "var(--radius-pill)",
            background: filled ? "var(--color-primary)" : active ? "var(--white)" : "var(--sand-200)",
            border: active && !filled ? "var(--border-width) solid var(--color-primary)" : "var(--border-width) solid transparent",
            color: filled ? "var(--white)" : "var(--olive-300)",
            transform: active ? "scale(1.12)" : "scale(1)",
            transition: "all var(--dur-normal) var(--ease-bounce)",
          }}>
            <Icon name="leaf" size={Math.round(size * 0.52)} strokeWidth={3} />
          </span>
        );
      })}
    </div>
  );
}
