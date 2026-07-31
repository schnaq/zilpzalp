import * as React from "react";

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  children?: React.ReactNode;
  tone?: "leaf" | "hoopoe" | "sun" | "clay" | "rare" | "sand";
  /** Lucide icon name shown before the text. */
  icon?: string;
}
export declare function Badge(props: BadgeProps): JSX.Element;
