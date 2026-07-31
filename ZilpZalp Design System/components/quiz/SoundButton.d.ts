import * as React from "react";

/**
 * Big round hoopoe-orange play button for bird calls.
 */
export interface SoundButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** True while the call is audible — swaps the glyph and pulses two rings. */
  playing?: boolean;
  /** Diameter in px. 120 minimum, 160 default. */
  size?: number;
  label?: string;
}
export declare function SoundButton(props: SoundButtonProps): JSX.Element;
