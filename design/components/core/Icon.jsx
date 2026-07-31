import React from "react";

/* Thin wrapper over the Lucide sprite (loaded from CDN by the host page).
   Kid-facing icons are always paired with a word or a photo — never alone. */
export function Icon({ name, size = 32, color = "currentColor", strokeWidth = 2.5, style, ...rest }) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    const el = ref.current;
    if (!el || !window.lucide) return;
    el.innerHTML = "";
    const i = document.createElement("i");
    i.setAttribute("data-lucide", name);
    el.appendChild(i);
    window.lucide.createIcons({
      attrs: { width: size, height: size, stroke: color, "stroke-width": strokeWidth },
      nameAttr: "data-lucide",
      root: el,
    });
  }, [name, size, color, strokeWidth]);
  return (
    <span
      ref={ref}
      aria-hidden="true"
      style={{ display: "inline-flex", width: size, height: size, flex: "0 0 auto", color, ...style }}
      {...rest}
    />
  );
}
