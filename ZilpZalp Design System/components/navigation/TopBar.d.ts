import * as React from "react";

export interface TopBarProps extends React.HTMLAttributes<HTMLElement> {
  onBack?: () => void;
  /** Opens the grown-ups area. */
  onSettings?: () => void;
  /** Usually a <QuizProgress />. */
  center?: React.ReactNode;
  /** Short title — grown-up screens only. */
  title?: string;
}
export declare function TopBar(props: TopBarProps): JSX.Element;
