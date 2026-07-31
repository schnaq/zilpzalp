import React from "react";

/* No logo files were provided, so the mark IS the word: Baloo 2 800, two-tone.
   "Zilp" in leaf green, "Zalp" in hoopoe orange. Replace when real art arrives. */
export function Wordmark({ size = 64, tone = "duo", style, ...rest }) {
  const a = tone === "mono-light" ? "var(--white)" : "var(--color-primary)";
  const b = tone === "mono-light" ? "var(--white)" : tone === "mono-dark" ? "var(--text-strong)" : "var(--color-accent)";
  const first = tone === "mono-dark" ? "var(--text-strong)" : a;
  return (
    <span
      style={{
        display: "inline-block", whiteSpace: "nowrap",
        font: `var(--weight-black) ${size}px/1 var(--font-display)`,
        letterSpacing: "var(--tracking-tight)", ...style,
      }}
      {...rest}
    >
      <span style={{ color: first }}>Zilp</span><span style={{ color: b }}>Zalp</span>
    </span>
  );
}
