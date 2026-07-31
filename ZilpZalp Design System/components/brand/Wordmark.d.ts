import * as React from "react";

/**
 * Type-only ZilpZalp lockup — placeholder for a real drawn mark.
 */
export interface WordmarkProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Cap height in px. 40 minimum. */
  size?: number;
  /** duo = green + orange; mono-light on photos/forest green; mono-dark on cream. */
  tone?: "duo" | "mono-light" | "mono-dark";
}
export declare function Wordmark(props: WordmarkProps): JSX.Element;
