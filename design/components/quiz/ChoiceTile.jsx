import React from "react";
import { Icon } from "../core/Icon.jsx";

/* One wordless answer in a bird quiz: a big photo tile a 4-year-old can hit.
   state drives the whole visual: idle -> chosen -> correct | retry */
/* Rubric tones: the tile body carries the full rubric colour, the photo field
   behind the bird is its lightest tint, border + ledge are the deep shade.
   [body, photoField, border, ledge, labelColour] */
const TONES = {
  papier: ["var(--cream-50)", "var(--sand-200)", "var(--sand-400)", "var(--sand-400)", "var(--text-strong)"],
  wald: ["var(--olive-500)", "var(--olive-100)", "var(--olive-700)", "var(--olive-700)", "var(--cream-50)"],
  wiese: ["var(--olive-400)", "var(--olive-50)", "var(--olive-600)", "var(--olive-600)", "var(--cream-50)"],
  rufe: ["var(--orange-500)", "var(--orange-50)", "var(--orange-700)", "var(--orange-700)", "var(--cream-50)"],
  belohnung: ["var(--sun-400)", "var(--sun-100)", "var(--sun-600)", "var(--sun-600)", "var(--ink-900)"],
  federn: ["var(--clay-500)", "var(--clay-50)", "var(--clay-700)", "var(--clay-700)", "var(--cream-50)"],
  rinde: ["var(--bark-500)", "var(--bark-100)", "var(--bark-700)", "var(--bark-700)", "var(--cream-50)"],
  beeren: ["var(--berry-500)", "var(--berry-100)", "var(--berry-700)", "var(--berry-700)", "var(--cream-50)"],
  sumpf: ["var(--marsh-500)", "var(--marsh-100)", "var(--marsh-700)", "var(--marsh-700)", "var(--cream-50)"],
};
const STATE = {
  idle: {},
  chosen: { border: "var(--color-accent)", ledge: "var(--orange-700)", ring: "var(--orange-100)" },
  correct: { border: "var(--color-correct)", ledge: "var(--olive-700)", ring: "var(--olive-200)" },
  retry: { border: "var(--color-retry)", ledge: "var(--sun-600)", ring: "var(--sun-200)" },
};

export function ChoiceTile({ photo, name, credit, tone = "papier", state = "idle", size = 260, onSelect, dimmed, style, ...rest }) {
  const [body, field, edge, ledge, label] = TONES[tone] || TONES.papier;
  const st = STATE[state] || STATE.idle;
  const s = { border: st.border || edge, ledge: st.ledge || ledge, ring: st.ring || "transparent" };
  const [down, setDown] = React.useState(false);
  return (
    <button
      type="button"
      aria-label={name}
      onClick={onSelect}
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      style={{
        position: "relative", display: "block", width: size, padding: 0,
        background: body,
        border: `var(--border-width-thick) solid ${s.border}`,
        borderRadius: "var(--radius-tile)",
        boxShadow: `0 ${down ? "2px" : "9px"} 0 ${s.ledge}, 0 0 0 ${s.ring === "transparent" ? 0 : "10px"} ${s.ring}`,
        transform: down ? "translateY(7px)" : state === "correct" ? "translateY(-4px)" : "translateY(0)",
        transition: "transform var(--dur-normal) var(--ease-bounce), box-shadow var(--dur-fast) var(--ease-out), border-color var(--dur-fast) var(--ease-out)",
        opacity: dimmed ? 0.4 : 1,
        overflow: "hidden", cursor: "pointer", WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      <span style={{
        position: "relative", display: "flex", alignItems: "center", justifyContent: "center",
        height: size * 0.78, background: photo ? `center/cover no-repeat url(${photo})` : field,
        color: "var(--bark-500)",
      }}>
        {photo ? null : <Icon name="bird" size={Math.round(size * 0.3)} />}
        {photo && credit ? (
          <span style={{
            position: "absolute", left: 0, right: 0, bottom: 0,
            padding: "14px 12px 7px", textAlign: "left",
            background: "linear-gradient(to top, rgba(42,34,19,.55), rgba(42,34,19,0))",
            font: "var(--weight-semibold) 13px/1.2 var(--font-body)", color: "var(--cream-50)",
          }}>{credit}</span>
        ) : null}
      </span>
      {name ? (
        <span style={{
          display: "block", padding: "10px 14px 14px",
          font: "var(--weight-bold) var(--text-label)/1.1 var(--font-display)",
          color: label, textAlign: "center",
        }}>{name}</span>
      ) : null}
      {state === "correct" || state === "retry" ? (
        <span style={{
          position: "absolute", top: 12, right: 12,
          width: 56, height: 56, borderRadius: "var(--radius-pill)",
          display: "flex", alignItems: "center", justifyContent: "center",
          background: state === "correct" ? "var(--color-correct)" : "var(--color-retry)",
          color: state === "correct" ? "var(--white)" : "var(--bark-700)",
          animation: "zz-pop var(--dur-slow) var(--ease-bounce) both",
        }}>
          <Icon name={state === "correct" ? "check" : "rotate-ccw"} size={30} strokeWidth={3.5} />
        </span>
      ) : null}
    </button>
  );
}
