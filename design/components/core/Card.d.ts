import * as React from "react";

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children?: React.ReactNode;
  /** Tinted paper surfaces. paper is the default; the tints group content by theme. */
  tone?: "paper" | "leaf" | "clay" | "sun" | "sand";
  /** CSS padding value. */
  pad?: string;
  elevation?: "none" | "sm" | "md" | "lg";
}
export declare function Card(props: CardProps): JSX.Element;
