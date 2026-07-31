import * as React from "react";

/**
 * A nest on the home tree — one activity entry point.
 */
export interface HomeTileProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Lucide icon name for the activity. */
  icon?: string;
  label?: string;
  tone?: "leaf" | "clay" | "sun" | "hoopoe";
  /** Stars earned, 0–3. */
  stars?: number;
  /** Not open yet: sand tile with an egg. */
  locked?: boolean;
  size?: number;
  onOpen?: () => void;
}
export declare function HomeTile(props: HomeTileProps): JSX.Element;
