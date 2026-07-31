import * as React from "react";

export interface SettingRowProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Lucide icon name. */
  icon?: string;
  label: string;
  /** Small explanatory line — grown-ups read this, kids never see it. */
  hint?: string;
  /** Right-hand value for a navigation row. */
  value?: React.ReactNode;
  /** Pass a boolean to render a switch instead of a value row. */
  on?: boolean;
  onToggle?: () => void;
}
export declare function SettingRow(props: SettingRowProps): JSX.Element;
