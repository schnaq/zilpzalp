import * as React from "react";

export interface QuizProgressProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Questions in this round. Rounds are 3–6 long. */
  total?: number;
  /** How many are answered. */
  done?: number;
  /** Index of the question in play — scales up. */
  current?: number;
  /** Dot diameter in px. */
  size?: number;
}
export declare function QuizProgress(props: QuizProgressProps): JSX.Element;
