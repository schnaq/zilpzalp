import * as React from "react";

export interface FeedbackBannerProps extends React.HTMLAttributes<HTMLDivElement> {
  children?: React.ReactNode;
  /** correct = leaf praise, retry = sunny encouragement, hint = sky nudge. */
  tone?: "correct" | "retry" | "hint";
  /** Override the default Lucide glyph. */
  icon?: string;
}
export declare function FeedbackBanner(props: FeedbackBannerProps): JSX.Element;
