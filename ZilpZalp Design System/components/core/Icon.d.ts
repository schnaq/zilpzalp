import * as React from "react";

export interface IconProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Lucide icon name, e.g. "volume-2", "star", "leaf". */
  name: string;
  /** Pixel box. Kid-facing icons are 32–64. */
  size?: number;
  color?: string;
  strokeWidth?: number;
}
export declare function Icon(props: IconProps): JSX.Element;
