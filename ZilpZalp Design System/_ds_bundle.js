/* @ds-bundle: {"format":4,"namespace":"ZilpZalpDesignSystem_bd8c6b","components":[{"name":"Wordmark","sourcePath":"components/brand/Wordmark.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"HomeTile","sourcePath":"components/navigation/HomeTile.jsx"},{"name":"SettingRow","sourcePath":"components/navigation/SettingRow.jsx"},{"name":"TopBar","sourcePath":"components/navigation/TopBar.jsx"},{"name":"ChoiceTile","sourcePath":"components/quiz/ChoiceTile.jsx"},{"name":"FeedbackBanner","sourcePath":"components/quiz/FeedbackBanner.jsx"},{"name":"QuizProgress","sourcePath":"components/quiz/QuizProgress.jsx"},{"name":"RewardSticker","sourcePath":"components/quiz/RewardSticker.jsx"},{"name":"SoundButton","sourcePath":"components/quiz/SoundButton.jsx"}],"sourceHashes":{"components/brand/Wordmark.jsx":"e95e31b7732a","components/core/Badge.jsx":"115f5d5d720d","components/core/Button.jsx":"726d6180979b","components/core/Card.jsx":"92e49738d1bd","components/core/Icon.jsx":"0ac8c1548a8d","components/core/IconButton.jsx":"28161affae51","components/navigation/HomeTile.jsx":"b0cf65a20cec","components/navigation/SettingRow.jsx":"bee8f2fe112e","components/navigation/TopBar.jsx":"69e9218fd571","components/quiz/ChoiceTile.jsx":"a92ce183ef4f","components/quiz/FeedbackBanner.jsx":"0919bcb58944","components/quiz/QuizProgress.jsx":"2138aeac4a23","components/quiz/RewardSticker.jsx":"e02137148645","components/quiz/SoundButton.jsx":"da374baa2c36","ui_kits/ipad_app/CollectionScreen.jsx":"882b803bc7f5","ui_kits/ipad_app/GrownupsScreen.jsx":"f3525d222489","ui_kits/ipad_app/HomeScreen.jsx":"7917c5e42d9a","ui_kits/ipad_app/QuizScreen.jsx":"176325ab6019","ui_kits/ipad_app/RewardScreen.jsx":"7db496e11ad4","ui_kits/ipad_app/birds.js":"d312c9086ed1"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.ZilpZalpDesignSystem_bd8c6b = window.ZilpZalpDesignSystem_bd8c6b || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/brand/Wordmark.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* No logo files were provided, so the mark IS the word: Baloo 2 800, two-tone.
   "Zilp" in leaf green, "Zalp" in hoopoe orange. Replace when real art arrives. */
function Wordmark({
  size = 64,
  tone = "duo",
  style,
  ...rest
}) {
  const a = tone === "mono-light" ? "var(--white)" : "var(--color-primary)";
  const b = tone === "mono-light" ? "var(--white)" : tone === "mono-dark" ? "var(--text-strong)" : "var(--color-accent)";
  const first = tone === "mono-dark" ? "var(--text-strong)" : a;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-block",
      whiteSpace: "nowrap",
      font: `var(--weight-black) ${size}px/1 var(--font-display)`,
      letterSpacing: "var(--tracking-tight)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      color: first
    }
  }, "Zilp"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: b
    }
  }, "Zalp"));
}
Object.assign(__ds_scope, { Wordmark });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/Wordmark.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  paper: {
    bg: "var(--surface-card)",
    border: "var(--border-card)"
  },
  leaf: {
    bg: "var(--olive-50)",
    border: "var(--olive-300)"
  },
  clay: {
    bg: "var(--clay-50)",
    border: "var(--clay-200)"
  },
  sun: {
    bg: "var(--sun-100)",
    border: "var(--sun-300)"
  },
  sand: {
    bg: "var(--surface-sunken)",
    border: "var(--sand-300)"
  }
};
function Card({
  children,
  tone = "paper",
  pad = "var(--space-5)",
  elevation = "md",
  style,
  ...rest
}) {
  const t = TONES[tone] || TONES.paper;
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: t.bg,
      border: `var(--border-width) solid ${t.border}`,
      borderRadius: "var(--radius-card)",
      boxShadow: elevation === "none" ? "none" : `var(--shadow-${elevation})`,
      padding: pad,
      color: "var(--text-body)",
      font: `var(--weight-semibold) var(--text-body)/var(--lh-body) var(--font-body)`,
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Thin wrapper over the Lucide sprite (loaded from CDN by the host page).
   Kid-facing icons are always paired with a word or a photo — never alone. */
function Icon({
  name,
  size = 32,
  color = "currentColor",
  strokeWidth = 2.5,
  style,
  ...rest
}) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    const el = ref.current;
    if (!el || !window.lucide) return;
    el.innerHTML = "";
    const i = document.createElement("i");
    i.setAttribute("data-lucide", name);
    el.appendChild(i);
    window.lucide.createIcons({
      attrs: {
        width: size,
        height: size,
        stroke: color,
        "stroke-width": strokeWidth
      },
      nameAttr: "data-lucide",
      root: el
    });
  }, [name, size, color, strokeWidth]);
  return /*#__PURE__*/React.createElement("span", _extends({
    ref: ref,
    "aria-hidden": "true",
    style: {
      display: "inline-flex",
      width: size,
      height: size,
      flex: "0 0 auto",
      color,
      ...style
    }
  }, rest));
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  leaf: ["var(--color-primary-soft)", "var(--olive-700)"],
  hoopoe: ["var(--color-accent-soft)", "var(--orange-700)"],
  sun: ["var(--sun-200)", "var(--bark-700)"],
  clay: ["var(--clay-100)", "var(--clay-700)"],
  rare: ["var(--berry-100)", "var(--berry-700)"],
  sand: ["var(--sand-200)", "var(--ink-700)"]
};
function Badge({
  children,
  tone = "leaf",
  icon,
  style,
  ...rest
}) {
  const [bg, fg] = TONES[tone] || TONES.leaf;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "var(--space-2)",
      padding: "8px 18px",
      background: bg,
      color: fg,
      borderRadius: "var(--radius-pill)",
      font: "var(--weight-bold) var(--text-body)/1 var(--font-display)",
      letterSpacing: "var(--tracking-loose)",
      whiteSpace: "nowrap",
      ...style
    }
  }, rest), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 22
  }) : null, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  primary: {
    bg: "var(--color-primary)",
    press: "var(--color-primary-press)",
    ledge: "var(--color-primary-shadow)",
    fg: "var(--text-on-color)"
  },
  accent: {
    bg: "var(--color-accent)",
    press: "var(--color-accent-press)",
    ledge: "var(--color-accent-shadow)",
    fg: "var(--text-on-color)"
  },
  reward: {
    bg: "var(--color-reward)",
    press: "var(--sun-500)",
    ledge: "var(--color-reward-shadow)",
    fg: "var(--text-on-reward)"
  },
  quiet: {
    bg: "var(--white)",
    press: "var(--cream-100)",
    ledge: "var(--sand-300)",
    fg: "var(--text-strong)"
  }
};
const SIZES = {
  md: {
    h: "var(--touch-min)",
    px: "var(--space-5)",
    fs: "var(--text-label)",
    icon: 26,
    ledge: "6px"
  },
  lg: {
    h: "var(--touch-comfy)",
    px: "var(--space-6)",
    fs: "var(--text-headline)",
    icon: 34,
    ledge: "8px"
  },
  xl: {
    h: "120px",
    px: "var(--space-7)",
    fs: "var(--text-title)",
    icon: 44,
    ledge: "10px"
  }
};
function Button({
  children,
  tone = "primary",
  size = "lg",
  icon,
  iconRight,
  block,
  disabled,
  onClick,
  style,
  ...rest
}) {
  const t = TONES[tone] || TONES.primary;
  const s = SIZES[size] || SIZES.lg;
  const [down, setDown] = React.useState(false);
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    disabled: disabled,
    onClick: onClick,
    onPointerDown: () => setDown(true),
    onPointerUp: () => setDown(false),
    onPointerLeave: () => {
      setDown(false);
      setHover(false);
    },
    onPointerEnter: () => setHover(true),
    style: {
      display: block ? "flex" : "inline-flex",
      width: block ? "100%" : "auto",
      alignItems: "center",
      justifyContent: "center",
      gap: "var(--space-3)",
      minHeight: s.h,
      padding: `0 ${s.px}`,
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
      ...style
    }
  }, rest), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: s.icon
  }) : null, children, iconRight ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: iconRight,
    size: s.icon
  }) : null);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  primary: ["var(--color-primary)", "var(--color-primary-shadow)", "var(--white)"],
  accent: ["var(--color-accent)", "var(--color-accent-shadow)", "var(--white)"],
  clay: ["var(--color-info)", "var(--clay-700)", "var(--white)"],
  quiet: ["var(--white)", "var(--sand-300)", "var(--text-strong)"]
};
function IconButton({
  icon,
  label,
  tone = "quiet",
  size = 96,
  onClick,
  disabled,
  style,
  ...rest
}) {
  const [bg, ledge, fg] = TONES[tone] || TONES.quiet;
  const [down, setDown] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": label,
    title: label,
    disabled: disabled,
    onClick: onClick,
    onPointerDown: () => setDown(true),
    onPointerUp: () => setDown(false),
    onPointerLeave: () => setDown(false),
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      width: size,
      height: size,
      flex: "0 0 auto",
      background: bg,
      color: fg,
      border: tone === "quiet" ? "var(--border-width) solid var(--border-strong)" : "none",
      borderRadius: "var(--radius-pill)",
      boxShadow: disabled ? "none" : `0 ${down ? "2px" : "7px"} 0 ${ledge}`,
      transform: down ? "translateY(5px)" : "translateY(0)",
      transition: "transform var(--dur-instant) var(--ease-out), box-shadow var(--dur-instant) var(--ease-out)",
      opacity: disabled ? 0.45 : 1,
      cursor: disabled ? "default" : "pointer",
      WebkitTapHighlightColor: "transparent",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: Math.round(size * 0.45)
  }));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/navigation/HomeTile.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  leaf: ["var(--olive-100)", "var(--color-primary)", "var(--olive-700)"],
  clay: ["var(--clay-100)", "var(--color-info)", "var(--clay-700)"],
  sun: ["var(--sun-200)", "var(--sun-400)", "var(--sun-600)"],
  hoopoe: ["var(--orange-100)", "var(--color-accent)", "var(--orange-700)"]
};

/* A nest on the home tree: one activity. Locked nests show an egg, not a padlock wall. */
function HomeTile({
  icon = "bird",
  label,
  tone = "leaf",
  stars = 0,
  locked,
  size = 240,
  onOpen,
  style,
  ...rest
}) {
  const [bg, edge, fg] = TONES[tone] || TONES.leaf;
  const [down, setDown] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": label,
    onClick: locked ? undefined : onOpen,
    onPointerDown: () => !locked && setDown(true),
    onPointerUp: () => setDown(false),
    onPointerLeave: () => setDown(false),
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      gap: "var(--space-3)",
      width: size,
      height: size,
      padding: "var(--space-4)",
      background: locked ? "var(--sand-200)" : bg,
      border: `var(--border-width-thick) solid ${locked ? "var(--sand-300)" : edge}`,
      borderRadius: "var(--radius-tile)",
      color: locked ? "var(--ink-300)" : fg,
      boxShadow: locked ? "none" : `0 ${down ? "3px" : "10px"} 0 ${edge}`,
      transform: down ? "translateY(7px)" : "translateY(0)",
      transition: "transform var(--dur-instant) var(--ease-out), box-shadow var(--dur-instant) var(--ease-out)",
      cursor: locked ? "default" : "pointer",
      WebkitTapHighlightColor: "transparent",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: locked ? "egg" : icon,
    size: Math.round(size * 0.34),
    strokeWidth: 2.5
  }), label ? /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--weight-bold) var(--text-label)/1.1 var(--font-display)",
      textAlign: "center"
    }
  }, label) : null, !locked && stars ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: "flex",
      gap: 4
    }
  }, Array.from({
    length: 3
  }, (_, i) => /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    key: i,
    name: "star",
    size: 24,
    color: i < stars ? "var(--sun-500)" : "var(--sand-400)",
    strokeWidth: 3
  }))) : null);
}
Object.assign(__ds_scope, { HomeTile });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/HomeTile.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SettingRow.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Grown-ups area only — the one place with small type and switches. */
function SettingRow({
  icon,
  label,
  hint,
  value,
  on,
  onToggle,
  style,
  ...rest
}) {
  const isSwitch = typeof on === "boolean";
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      alignItems: "center",
      gap: "var(--space-4)",
      padding: "var(--space-4) var(--space-5)",
      background: "var(--surface-card)",
      borderBottom: "2px solid var(--border-card)",
      font: "var(--weight-semibold) var(--text-body)/var(--lh-body) var(--font-body)",
      color: "var(--text-body)",
      ...style
    }
  }, rest), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 28,
    color: "var(--olive-600)"
  }) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--text-strong)",
      fontWeight: "var(--weight-bold)"
    }
  }, label), hint ? /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "var(--text-caption)",
      color: "var(--text-muted)",
      marginTop: 2
    }
  }, hint) : null), isSwitch ? /*#__PURE__*/React.createElement("button", {
    type: "button",
    role: "switch",
    "aria-checked": on,
    "aria-label": label,
    onClick: onToggle,
    style: {
      width: 72,
      height: 40,
      padding: 4,
      border: "none",
      cursor: "pointer",
      borderRadius: "var(--radius-pill)",
      background: on ? "var(--color-primary)" : "var(--sand-300)",
      transition: "background var(--dur-fast) var(--ease-out)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      width: 32,
      height: 32,
      borderRadius: "var(--radius-pill)",
      background: "var(--white)",
      boxShadow: "var(--shadow-sm)",
      transform: on ? "translateX(32px)" : "translateX(0)",
      transition: "transform var(--dur-fast) var(--ease-bounce)"
    }
  })) : /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-muted)",
      display: "flex",
      alignItems: "center",
      gap: "var(--space-2)"
    }
  }, value, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-right",
    size: 22
  })));
}
Object.assign(__ds_scope, { SettingRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SettingRow.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TopBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Fixed iPad header: back at left, wordless progress centred, grown-up door at right. */
function TopBar({
  onBack,
  onSettings,
  center,
  title,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("header", _extends({
    style: {
      display: "flex",
      alignItems: "center",
      gap: "var(--space-5)",
      padding: "var(--space-4) var(--gutter-screen)",
      background: "color-mix(in oklab, var(--cream-50) 90%, transparent)",
      backdropFilter: "blur(12px)",
      borderBottom: "var(--border-width) solid var(--border-card)",
      ...style
    }
  }, rest), onBack ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "chevron-left",
    label: "Zur\xFCck",
    size: 72,
    onClick: onBack
  }) : /*#__PURE__*/React.createElement("span", {
    style: {
      width: 72
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: "var(--space-4)"
    }
  }, title ? /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--weight-bold) var(--text-headline)/1 var(--font-display)",
      color: "var(--text-strong)"
    }
  }, title) : null, center), onSettings ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "user-round-cog",
    label: "F\xFCr Erwachsene",
    size: 72,
    onClick: onSettings
  }) : /*#__PURE__*/React.createElement("span", {
    style: {
      width: 72
    }
  }));
}
Object.assign(__ds_scope, { TopBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TopBar.jsx", error: String((e && e.message) || e) }); }

// components/quiz/ChoiceTile.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
  sumpf: ["var(--marsh-500)", "var(--marsh-100)", "var(--marsh-700)", "var(--marsh-700)", "var(--cream-50)"]
};
const STATE = {
  idle: {},
  chosen: {
    border: "var(--color-accent)",
    ledge: "var(--orange-700)",
    ring: "var(--orange-100)"
  },
  correct: {
    border: "var(--color-correct)",
    ledge: "var(--olive-700)",
    ring: "var(--olive-200)"
  },
  retry: {
    border: "var(--color-retry)",
    ledge: "var(--sun-600)",
    ring: "var(--sun-200)"
  }
};
function ChoiceTile({
  photo,
  name,
  credit,
  tone = "papier",
  state = "idle",
  size = 260,
  onSelect,
  dimmed,
  style,
  ...rest
}) {
  const [body, field, edge, ledge, label] = TONES[tone] || TONES.papier;
  const st = STATE[state] || STATE.idle;
  const s = {
    border: st.border || edge,
    ledge: st.ledge || ledge,
    ring: st.ring || "transparent"
  };
  const [down, setDown] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": name,
    onClick: onSelect,
    onPointerDown: () => setDown(true),
    onPointerUp: () => setDown(false),
    onPointerLeave: () => setDown(false),
    style: {
      position: "relative",
      display: "block",
      width: size,
      padding: 0,
      background: body,
      border: `var(--border-width-thick) solid ${s.border}`,
      borderRadius: "var(--radius-tile)",
      boxShadow: `0 ${down ? "2px" : "9px"} 0 ${s.ledge}, 0 0 0 ${s.ring === "transparent" ? 0 : "10px"} ${s.ring}`,
      transform: down ? "translateY(7px)" : state === "correct" ? "translateY(-4px)" : "translateY(0)",
      transition: "transform var(--dur-normal) var(--ease-bounce), box-shadow var(--dur-fast) var(--ease-out), border-color var(--dur-fast) var(--ease-out)",
      opacity: dimmed ? 0.4 : 1,
      overflow: "hidden",
      cursor: "pointer",
      WebkitTapHighlightColor: "transparent",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      height: size * 0.78,
      background: photo ? `center/cover no-repeat url(${photo})` : field,
      color: "var(--bark-500)"
    }
  }, photo ? null : /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "bird",
    size: Math.round(size * 0.3)
  }), photo && credit ? /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      left: 0,
      right: 0,
      bottom: 0,
      padding: "14px 12px 7px",
      textAlign: "left",
      background: "linear-gradient(to top, rgba(42,34,19,.55), rgba(42,34,19,0))",
      font: "var(--weight-semibold) 13px/1.2 var(--font-body)",
      color: "var(--cream-50)"
    }
  }, credit) : null), name ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      padding: "10px 14px 14px",
      font: "var(--weight-bold) var(--text-label)/1.1 var(--font-display)",
      color: label,
      textAlign: "center"
    }
  }, name) : null, state === "correct" || state === "retry" ? /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      top: 12,
      right: 12,
      width: 56,
      height: 56,
      borderRadius: "var(--radius-pill)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      background: state === "correct" ? "var(--color-correct)" : "var(--color-retry)",
      color: state === "correct" ? "var(--white)" : "var(--bark-700)",
      animation: "zz-pop var(--dur-slow) var(--ease-bounce) both"
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: state === "correct" ? "check" : "rotate-ccw",
    size: 30,
    strokeWidth: 3.5
  })) : null);
}
Object.assign(__ds_scope, { ChoiceTile });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/quiz/ChoiceTile.jsx", error: String((e && e.message) || e) }); }

// components/quiz/FeedbackBanner.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  correct: ["var(--color-correct-soft)", "var(--color-correct)", "var(--olive-800)", "party-popper"],
  retry: ["var(--color-retry-soft)", "var(--color-retry)", "var(--bark-700)", "hand-heart"],
  hint: ["var(--clay-50)", "var(--clay-300)", "var(--clay-700)", "lightbulb"]
};
function FeedbackBanner({
  children,
  tone = "correct",
  icon,
  style,
  ...rest
}) {
  const [bg, edge, fg, defIcon] = TONES[tone] || TONES.correct;
  return /*#__PURE__*/React.createElement("div", _extends({
    role: "status",
    style: {
      display: "flex",
      alignItems: "center",
      gap: "var(--space-4)",
      padding: "var(--space-4) var(--space-6)",
      background: bg,
      border: `var(--border-width) solid ${edge}`,
      borderRadius: "var(--radius-pill)",
      color: fg,
      font: "var(--weight-bold) var(--text-headline)/1.2 var(--font-display)",
      boxShadow: "var(--shadow-sm)",
      animation: "zz-pop var(--dur-slow) var(--ease-bounce) both",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon || defIcon,
    size: 38
  }), /*#__PURE__*/React.createElement("span", null, children));
}
Object.assign(__ds_scope, { FeedbackBanner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/quiz/FeedbackBanner.jsx", error: String((e && e.message) || e) }); }

// components/quiz/QuizProgress.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Wordless progress: one leaf per question. Filled = answered right. */
function QuizProgress({
  total = 5,
  done = 0,
  current = 0,
  size = 44,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    role: "img",
    "aria-label": `${done} von ${total}`,
    style: {
      display: "flex",
      gap: "var(--space-3)",
      alignItems: "center",
      ...style
    }
  }, rest), Array.from({
    length: total
  }, (_, i) => {
    const filled = i < done;
    const active = i === current;
    return /*#__PURE__*/React.createElement("span", {
      key: i,
      style: {
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        width: size,
        height: size,
        borderRadius: "var(--radius-pill)",
        background: filled ? "var(--color-primary)" : active ? "var(--white)" : "var(--sand-200)",
        border: active && !filled ? "var(--border-width) solid var(--color-primary)" : "var(--border-width) solid transparent",
        color: filled ? "var(--white)" : "var(--olive-300)",
        transform: active ? "scale(1.12)" : "scale(1)",
        transition: "all var(--dur-normal) var(--ease-bounce)"
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "leaf",
      size: Math.round(size * 0.52),
      strokeWidth: 3
    }));
  }));
}
Object.assign(__ds_scope, { QuizProgress });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/quiz/QuizProgress.jsx", error: String((e && e.message) || e) }); }

// components/quiz/RewardSticker.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  sun: ["var(--sun-300)", "var(--sun-600)", "var(--bark-700)"],
  leaf: ["var(--olive-200)", "var(--olive-600)", "var(--olive-800)"],
  hoopoe: ["var(--orange-200)", "var(--orange-600)", "var(--orange-700)"],
  rare: ["var(--berry-300)", "var(--berry-700)", "var(--white)"]
};

/* Earned collectible. Locked stickers stay visible but greyed — kids need to see what's next. */
function RewardSticker({
  icon = "star",
  photo,
  credit,
  label,
  tone = "sun",
  locked,
  size = 140,
  style,
  ...rest
}) {
  const [bg, edge, fg] = TONES[tone] || TONES.sun;
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "inline-flex",
      flexDirection: "column",
      alignItems: "center",
      gap: "var(--space-2)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      width: size,
      height: size,
      borderRadius: "var(--radius-pill)",
      background: locked ? "var(--sand-200)" : bg,
      border: `var(--border-width-thick) solid ${locked ? "var(--sand-300)" : edge}`,
      color: locked ? "var(--ink-300)" : fg,
      boxShadow: locked ? "none" : "var(--shadow-md)",
      transform: locked ? "none" : "rotate(-4deg)",
      overflow: "hidden",
      position: "relative"
    }
  }, photo && !locked ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("img", {
    src: photo,
    alt: "",
    style: {
      width: "100%",
      height: "100%",
      objectFit: "cover",
      display: "block"
    }
  }), credit ? /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      left: 0,
      right: 0,
      bottom: 0,
      padding: "12px 8px 5px",
      textAlign: "center",
      background: "linear-gradient(to top, rgba(42,34,19,.55), rgba(42,34,19,0))",
      font: "var(--weight-semibold) 11px/1.2 var(--font-body)",
      color: "var(--cream-50)"
    }
  }, credit) : null) : /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: locked ? "lock" : icon,
    size: Math.round(size * 0.45),
    strokeWidth: 2.5
  })), label ? /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--weight-bold) var(--text-body)/1.2 var(--font-display)",
      color: locked ? "var(--text-muted)" : "var(--text-strong)",
      textAlign: "center",
      maxWidth: size + 40
    }
  }, label) : null);
}
Object.assign(__ds_scope, { RewardSticker });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/quiz/RewardSticker.jsx", error: String((e && e.message) || e) }); }

// components/quiz/SoundButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* The "listen again" control. Rings pulse outward while playing. */
function SoundButton({
  playing,
  size = 160,
  label = "Nochmal hören",
  onClick,
  style,
  ...rest
}) {
  const [down, setDown] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": label,
    onClick: onClick,
    onPointerDown: () => setDown(true),
    onPointerUp: () => setDown(false),
    onPointerLeave: () => setDown(false),
    style: {
      position: "relative",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      width: size,
      height: size,
      border: "none",
      padding: 0,
      borderRadius: "var(--radius-pill)",
      background: "var(--color-accent)",
      color: "var(--white)",
      boxShadow: `0 ${down ? "3px" : "10px"} 0 var(--color-accent-shadow)`,
      transform: down ? "translateY(7px)" : "translateY(0)",
      transition: "transform var(--dur-instant) var(--ease-out), box-shadow var(--dur-instant) var(--ease-out)",
      cursor: "pointer",
      WebkitTapHighlightColor: "transparent",
      ...style
    }
  }, rest), playing ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", {
    style: ring(size, 0)
  }), /*#__PURE__*/React.createElement("span", {
    style: ring(size, 0.45)
  })) : null, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: playing ? "volume-2" : "play",
    size: Math.round(size * 0.4),
    strokeWidth: 3
  }));
}
function ring(size, delay) {
  return {
    position: "absolute",
    inset: 0,
    borderRadius: "var(--radius-pill)",
    border: "var(--border-width-thick) solid var(--color-accent)",
    animation: `zz-ring 1.4s var(--ease-out) ${delay}s infinite`,
    pointerEvents: "none"
  };
}
Object.assign(__ds_scope, { SoundButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/quiz/SoundButton.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ipad_app/CollectionScreen.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const {
  TopBar,
  RewardSticker,
  Card,
  Badge,
  Button
} = window.ZilpZalpDesignSystem_bd8c6b;
const TONE = ['leaf', 'hoopoe', 'sun', 'leaf', 'rare', 'hoopoe'];
const FOUND = ['zilpzalp', 'wiedehopf', 'amsel', 'blaumeise', 'eisvogel'];
const BIRDS = FOUND.map((slug, i) => {
  const b = (window.ZZ_BIRDS || []).find(x => x.slug === slug) || {};
  return {
    photo: b.photo,
    credit: b.credit,
    label: b.name || slug,
    tone: TONE[i]
  };
}).concat([{
  label: 'Noch geheim',
  locked: true
}, {
  label: 'Noch geheim',
  locked: true
}, {
  label: 'Noch geheim',
  locked: true
}]);

/* The album: every bird a child has met, plus the empty spots ahead. */
function CollectionScreen({
  go
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      background: 'var(--surface-page)'
    }
  }, /*#__PURE__*/React.createElement(TopBar, {
    onBack: () => go('home'),
    onSettings: () => go('grownups'),
    title: "Meine Sammlung"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 'var(--space-6) var(--gutter-screen)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 'var(--space-3)',
      marginBottom: 'var(--space-6)'
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: "leaf",
    icon: "leaf"
  }, "5 V\xF6gel"), /*#__PURE__*/React.createElement(Badge, {
    tone: "sun",
    icon: "star"
  }, "11 Sterne"), /*#__PURE__*/React.createElement(Badge, {
    tone: "rare",
    icon: "sparkles"
  }, "1 seltener Fund")), /*#__PURE__*/React.createElement(Card, {
    tone: "paper",
    pad: "var(--space-6)"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(4, 1fr)',
      gap: 'var(--space-6) var(--space-5)',
      justifyItems: 'center'
    }
  }, BIRDS.map((b, i) => /*#__PURE__*/React.createElement(RewardSticker, _extends({
    key: i
  }, b, {
    size: 150
  }))))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      marginTop: 'var(--space-6)'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    tone: "accent",
    size: "lg",
    icon: "play",
    onClick: () => go('quiz')
  }, "Neuen Vogel finden"))));
}
Object.assign(window, {
  CollectionScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ipad_app/CollectionScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ipad_app/GrownupsScreen.jsx
try { (() => {
const {
  TopBar,
  Card,
  SettingRow,
  Button,
  Badge
} = window.ZilpZalpDesignSystem_bd8c6b;

/* The only screen with small type, switches and full sentences. */
function GrownupsScreen({
  go
}) {
  const [sound, setSound] = React.useState(true);
  const [music, setMusic] = React.useState(false);
  const [names, setNames] = React.useState(true);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      background: 'var(--surface-page)'
    }
  }, /*#__PURE__*/React.createElement(TopBar, {
    onBack: () => go('home'),
    title: "F\xFCr Erwachsene"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 'var(--max-content)',
      margin: '0 auto',
      padding: 'var(--space-6) var(--gutter-screen)'
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--weight-semibold) var(--text-body-lg)/var(--lh-body-lg) var(--font-body)',
      color: 'var(--text-body)',
      marginTop: 0
    }
  }, "ZilpZalp lernt V\xF6gel \xFCber Rufe und Bilder \u2014 ohne Lesen, ohne Punktejagd. Hier stellen Sie ein, wie lange und wie laut gespielt wird."), /*#__PURE__*/React.createElement(Card, {
    pad: "0",
    style: {
      overflow: 'hidden',
      marginBottom: 'var(--space-6)'
    }
  }, /*#__PURE__*/React.createElement(SettingRow, {
    icon: "volume-2",
    label: "Vogelstimmen",
    hint: "Echte Aufnahmen aus der Sammlung",
    on: sound,
    onToggle: () => setSound(!sound)
  }), /*#__PURE__*/React.createElement(SettingRow, {
    icon: "music",
    label: "Hintergrundmusik",
    hint: "Leise Waldger\xE4usche zwischen den Runden",
    on: music,
    onToggle: () => setMusic(!music)
  }), /*#__PURE__*/React.createElement(SettingRow, {
    icon: "type",
    label: "Namen anzeigen",
    hint: "Vogelnamen unter den Bildern einblenden",
    on: names,
    onToggle: () => setNames(!names)
  }), /*#__PURE__*/React.createElement(SettingRow, {
    icon: "clock",
    label: "Spielzeit pro Tag",
    value: "20 Min"
  }), /*#__PURE__*/React.createElement(SettingRow, {
    icon: "languages",
    label: "Sprache",
    value: "Deutsch"
  }), /*#__PURE__*/React.createElement(SettingRow, {
    icon: "camera",
    label: "Fotos & Dank",
    hint: "Alle Vogelfotos von iNaturalist, CC BY \u2014 Namensnennung",
    value: (window.ZZ_BIRDS || []).length + " Fotos",
    style: {
      borderBottom: 'none'
    }
  })), /*#__PURE__*/React.createElement(Card, {
    pad: "var(--space-5)",
    tone: "sand",
    style: {
      marginBottom: 'var(--space-6)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--weight-bold) var(--text-headline)/1.2 var(--font-display)',
      color: 'var(--text-strong)',
      marginBottom: 'var(--space-3)'
    }
  }, "Fotos & Dank"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: '6px 24px'
    }
  }, (window.ZZ_BIRDS || []).map(b => /*#__PURE__*/React.createElement("div", {
    key: b.slug,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      gap: 'var(--space-4)',
      font: 'var(--weight-semibold) var(--text-caption)/1.5 var(--font-body)',
      color: 'var(--text-muted)',
      borderBottom: '2px solid var(--sand-300)',
      paddingBottom: 4
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-strong)'
    }
  }, b.name), /*#__PURE__*/React.createElement("span", null, b.credit)))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 'var(--space-4)',
      font: 'var(--weight-semibold) var(--text-caption)/1.5 var(--font-body)',
      color: 'var(--text-muted)'
    }
  }, "Quelle: iNaturalist, Lizenz CC BY 4.0. Details in assets/photos/CREDITS.md")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 'var(--space-4)'
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: "sand",
    icon: "shield-check"
  }, "Keine Werbung, keine K\xE4ufe"), /*#__PURE__*/React.createElement(Button, {
    tone: "quiet",
    size: "md",
    icon: "chevron-left",
    onClick: () => go('home')
  }, "Zur\xFCck zum Spiel"))));
}
Object.assign(window, {
  GrownupsScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ipad_app/GrownupsScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ipad_app/HomeScreen.jsx
try { (() => {
const {
  TopBar,
  HomeTile,
  Wordmark,
  Badge,
  IconButton
} = window.ZilpZalpDesignSystem_bd8c6b;

/* Home = the tree. Nests (activities) sit on branches; the crown is cream sky. */
function HomeScreen({
  go,
  stars
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      display: 'flex',
      flexDirection: 'column',
      background: 'linear-gradient(180deg, var(--orange-50) 0%, var(--cream-100) 46%, var(--olive-100) 100%)'
    }
  }, /*#__PURE__*/React.createElement(TopBar, {
    onSettings: () => go('grownups'),
    center: /*#__PURE__*/React.createElement(Wordmark, {
      size: 44
    })
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      position: 'relative',
      padding: '32px var(--gutter-screen) 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginBottom: 26
    }
  }, /*#__PURE__*/React.createElement("h1", {
    style: {
      margin: 0,
      font: 'var(--weight-black) var(--text-display-2)/var(--lh-display-2) var(--font-display)',
      color: 'var(--text-strong)'
    }
  }, "Was m\xF6chtest du machen?"), /*#__PURE__*/React.createElement(Badge, {
    tone: "sun",
    icon: "star"
  }, stars, " Sterne")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: 470
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      bottom: 0,
      width: 92,
      height: 400,
      marginLeft: -46,
      background: 'var(--bark-500)',
      borderRadius: '40px 40px 0 0'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      bottom: 250,
      width: 300,
      height: 34,
      marginLeft: -300,
      background: 'var(--bark-500)',
      borderRadius: 'var(--radius-pill)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      bottom: 170,
      width: 300,
      height: 34,
      background: 'var(--bark-500)',
      borderRadius: 'var(--radius-pill)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'grid',
      gridTemplateColumns: 'repeat(2, 240px)',
      justifyContent: 'space-between',
      rowGap: 40
    }
  }, /*#__PURE__*/React.createElement(HomeTile, {
    icon: "volume-2",
    label: "Wer singt da?",
    tone: "leaf",
    stars: 3,
    onOpen: () => go('quiz')
  }), /*#__PURE__*/React.createElement(HomeTile, {
    icon: "bird",
    label: "Wer ist das?",
    tone: "hoopoe",
    stars: 2,
    onOpen: () => go('quiz')
  }), /*#__PURE__*/React.createElement(HomeTile, {
    icon: "feather",
    label: "Federn finden",
    tone: "clay",
    stars: 1,
    onOpen: () => go('quiz')
  }), /*#__PURE__*/React.createElement(HomeTile, {
    label: "Bald!",
    locked: true
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      gap: 'var(--space-5)',
      padding: '0 0 var(--space-6)'
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    icon: "album",
    label: "Meine Sammlung",
    tone: "primary",
    onClick: () => go('collection')
  }), /*#__PURE__*/React.createElement(IconButton, {
    icon: "map",
    label: "Karte",
    tone: "clay"
  }), /*#__PURE__*/React.createElement(IconButton, {
    icon: "music",
    label: "Lieder",
    tone: "accent"
  })));
}
Object.assign(window, {
  HomeScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ipad_app/HomeScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ipad_app/QuizScreen.jsx
try { (() => {
const {
  TopBar,
  QuizProgress,
  ChoiceTile,
  SoundButton,
  FeedbackBanner,
  Button
} = window.ZilpZalpDesignSystem_bd8c6b;
const B = slug => (window.ZZ_BIRDS || []).find(b => b.slug === slug) || {};
const ROUND = [{
  ...B('zilpzalp'),
  tone: 'wald',
  ok: true
}, {
  ...B('amsel'),
  tone: 'beeren'
}, {
  ...B('wiedehopf'),
  tone: 'rufe'
}, {
  ...B('blaumeise'),
  tone: 'sumpf'
}];

/* Listen to the call, tap the bird. No words needed to play. */
function QuizScreen({
  go,
  onScore
}) {
  const [picked, setPicked] = React.useState(null);
  const [playing, setPlaying] = React.useState(true);
  React.useEffect(() => {
    const t = setTimeout(() => setPlaying(false), 2600);
    return () => clearTimeout(t);
  }, [playing]);
  const right = picked !== null && ROUND[picked].ok;
  const pick = i => {
    if (right) return;
    setPicked(i);
    if (ROUND[i].ok) onScore();
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      display: 'flex',
      flexDirection: 'column',
      background: 'var(--surface-page)'
    }
  }, /*#__PURE__*/React.createElement(TopBar, {
    onBack: () => go('home'),
    onSettings: () => go('grownups'),
    center: /*#__PURE__*/React.createElement(QuizProgress, {
      total: 5,
      done: 2,
      current: 2
    })
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: '20px var(--gutter-screen) 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 'var(--space-6)',
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement(SoundButton, {
    playing: playing,
    size: 150,
    onClick: () => setPlaying(true)
  }), /*#__PURE__*/React.createElement("h1", {
    style: {
      margin: 0,
      font: 'var(--weight-black) var(--text-display-2)/var(--lh-display-2) var(--font-display)',
      color: 'var(--text-strong)'
    }
  }, "Wer singt da?")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(4, 1fr)',
      gap: 'var(--gap-tiles)',
      width: '100%'
    }
  }, ROUND.map((b, i) => /*#__PURE__*/React.createElement(ChoiceTile, {
    key: b.name,
    name: b.name,
    photo: b.photo,
    credit: b.credit,
    tone: b.tone,
    size: 230,
    state: picked === i ? b.ok ? 'correct' : 'retry' : 'idle',
    dimmed: right && !b.ok,
    onSelect: () => pick(i)
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: 100,
      display: 'flex',
      alignItems: 'center',
      gap: 'var(--space-5)',
      marginTop: 'var(--space-5)'
    }
  }, picked === null ? null : right ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(FeedbackBanner, {
    tone: "correct"
  }, "Genau! Das ist der Zilpzalp."), /*#__PURE__*/React.createElement(Button, {
    tone: "primary",
    iconRight: "arrow-right",
    onClick: () => go('reward')
  }, "Weiter")) : /*#__PURE__*/React.createElement(FeedbackBanner, {
    tone: "retry"
  }, "Fast! H\xF6r nochmal hin."))));
}
Object.assign(window, {
  QuizScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ipad_app/QuizScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ipad_app/RewardScreen.jsx
try { (() => {
const {
  RewardSticker,
  Button,
  Wordmark
} = window.ZilpZalpDesignSystem_bd8c6b;
const ZZ = (window.ZZ_BIRDS || []).find(b => b.slug === 'zilpzalp') || {};

/* Celebration: one new sticker, two ways out. Full-bleed forest green. */
function RewardScreen({
  go
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      minHeight: '100%',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 'var(--space-6)',
      background: 'var(--surface-forest)',
      textAlign: 'center',
      padding: 'var(--gutter-screen)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10
    }
  }, [0, 1, 2].map(i => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      width: 26,
      height: 26,
      borderRadius: '999px',
      background: 'var(--sun-400)',
      animation: `zz-bob 1.4s var(--ease-in-out) ${i * 0.15}s infinite`
    }
  }))), /*#__PURE__*/React.createElement("h1", {
    style: {
      margin: 0,
      font: 'var(--weight-black) var(--text-hero)/var(--lh-hero) var(--font-display)',
      color: 'var(--white)'
    }
  }, "Gut gemacht!"), /*#__PURE__*/React.createElement("div", {
    style: {
      animation: 'zz-pop var(--dur-celebrate) var(--ease-bounce) both'
    }
  }, /*#__PURE__*/React.createElement(RewardSticker, {
    photo: ZZ.photo,
    credit: ZZ.credit,
    label: (ZZ.name || 'Zilpzalp') + ' gesammelt',
    tone: "sun",
    size: 200
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 'var(--space-5)'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    tone: "reward",
    size: "lg",
    icon: "album",
    onClick: () => go('collection')
  }, "Sammlung"), /*#__PURE__*/React.createElement(Button, {
    tone: "primary",
    size: "lg",
    iconRight: "arrow-right",
    onClick: () => go('quiz')
  }, "Nochmal spielen")), /*#__PURE__*/React.createElement(Wordmark, {
    size: 34,
    tone: "mono-light",
    style: {
      opacity: 0.55
    }
  }));
}
Object.assign(window, {
  RewardScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ipad_app/RewardScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ipad_app/birds.js
try { (() => {
/* Photo data for the UI kit. Credits are mandatory (CC BY) — see assets/photos/CREDITS.md */
window.ZZ_BIRDS = [{
  "slug": "zilpzalp",
  "name": "Zilpzalp",
  "latin": "Phylloscopus collybita",
  "photo": "../../assets/photos/zilpzalp.png",
  "credit": "Foto: Tomas Broucek (CC BY)"
}, {
  "slug": "wiedehopf",
  "name": "Wiedehopf",
  "latin": "Upupa epops",
  "photo": "../../assets/photos/wiedehopf.png",
  "credit": "Foto: Dmitry Ivanov (CC BY)"
}, {
  "slug": "amsel",
  "name": "Amsel",
  "latin": "Turdus merula",
  "photo": "../../assets/photos/amsel.png",
  "credit": "Foto: Alexis Tinker-Tsavalas (CC BY)"
}, {
  "slug": "blaumeise",
  "name": "Blaumeise",
  "latin": "Cyanistes caeruleus",
  "photo": "../../assets/photos/blaumeise.png",
  "credit": "Foto: Thorsten Hackbarth (CC BY)"
}, {
  "slug": "kohlmeise",
  "name": "Kohlmeise",
  "latin": "Parus major",
  "photo": "../../assets/photos/kohlmeise.png",
  "credit": "Foto: SteveM4560 (CC BY)"
}, {
  "slug": "rotkehlchen",
  "name": "Rotkehlchen",
  "latin": "Erithacus rubecula",
  "photo": "../../assets/photos/rotkehlchen.png",
  "credit": "Foto: Alexis Tinker-Tsavalas (CC BY)"
}, {
  "slug": "buntspecht",
  "name": "Buntspecht",
  "latin": "Dendrocopos major",
  "photo": "../../assets/photos/buntspecht.png",
  "credit": "Foto: Вячеслав Юсупов (CC BY)"
}, {
  "slug": "eisvogel",
  "name": "Eisvogel",
  "latin": "Alcedo atthis",
  "photo": "../../assets/photos/eisvogel.png",
  "credit": "Foto: Alexis Lours (CC BY)"
}, {
  "slug": "star",
  "name": "Star",
  "latin": "Sturnus vulgaris",
  "photo": "../../assets/photos/star.png",
  "credit": "Foto: egorbirder (CC BY)"
}, {
  "slug": "hausrotschwanz",
  "name": "Hausrotschwanz",
  "latin": "Phoenicurus ochruros",
  "photo": "../../assets/photos/hausrotschwanz.png",
  "credit": "Foto: SteveM4560 (CC BY)"
}];
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ipad_app/birds.js", error: String((e && e.message) || e) }); }

__ds_ns.Wordmark = __ds_scope.Wordmark;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.HomeTile = __ds_scope.HomeTile;

__ds_ns.SettingRow = __ds_scope.SettingRow;

__ds_ns.TopBar = __ds_scope.TopBar;

__ds_ns.ChoiceTile = __ds_scope.ChoiceTile;

__ds_ns.FeedbackBanner = __ds_scope.FeedbackBanner;

__ds_ns.QuizProgress = __ds_scope.QuizProgress;

__ds_ns.RewardSticker = __ds_scope.RewardSticker;

__ds_ns.SoundButton = __ds_scope.SoundButton;

})();
