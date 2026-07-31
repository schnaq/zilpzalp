import * as React from "react";

export interface IconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Lucide icon name. */
  icon: string;
  /** Spoken/assistive label — required, since there is no visible text. */
  label: string;
  tone?: "primary" | "accent" | "clay" | "quiet";
  /** Diameter in px. 64 is the floor, 96 the kid default. */
  size?: number;
  disabled?: boolean;
}
export declare function IconButton(props: IconButtonProps): JSX.Element;
