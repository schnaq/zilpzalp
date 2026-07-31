import * as React from "react";

/**
 * The one pressable text control. Chunky pill with a solid colour ledge that
 * squishes down on press.
 */
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children?: React.ReactNode;
  /** primary = leaf green go/next. accent = hoopoe orange, one per screen. reward = sun yellow, celebrations. quiet = grown-up / secondary. */
  tone?: "primary" | "accent" | "reward" | "quiet";
  /** md is grown-up areas only; lg is the kid default; xl is a full-screen call to action. */
  size?: "md" | "lg" | "xl";
  /** Lucide icon name shown before the label. */
  icon?: string;
  /** Lucide icon name shown after the label. */
  iconRight?: string;
  block?: boolean;
  disabled?: boolean;
}
export declare function Button(props: ButtonProps): JSX.Element;
