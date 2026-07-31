import React from "react";
import { Icon } from "../core/Icon.jsx";

/* The "listen again" control. Rings pulse outward while playing. */
export function SoundButton({ playing, size = 160, label = "Nochmal hören", onClick, style, ...rest }) {
  const [down, setDown] = React.useState(false);
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      style={{
        position: "relative", display: "inline-flex", alignItems: "center", justifyContent: "center",
        width: size, height: size, border: "none", padding: 0,
        borderRadius: "var(--radius-pill)",
        background: "var(--color-accent)", color: "var(--white)",
        boxShadow: `0 ${down ? "3px" : "10px"} 0 var(--color-accent-shadow)`,
        transform: down ? "translateY(7px)" : "translateY(0)",
        transition: "transform var(--dur-instant) var(--ease-out), box-shadow var(--dur-instant) var(--ease-out)",
        cursor: "pointer", WebkitTapHighlightColor: "transparent",
        ...style,
      }}
      {...rest}
    >
      {playing ? (
        <>
          <span style={ring(size, 0)} />
          <span style={ring(size, 0.45)} />
        </>
      ) : null}
      <Icon name={playing ? "volume-2" : "play"} size={Math.round(size * 0.4)} strokeWidth={3} />
    </button>
  );
}

function ring(size, delay) {
  return {
    position: "absolute", inset: 0, borderRadius: "var(--radius-pill)",
    border: "var(--border-width-thick) solid var(--color-accent)",
    animation: `zz-ring 1.4s var(--ease-out) ${delay}s infinite`,
    pointerEvents: "none",
  };
}
