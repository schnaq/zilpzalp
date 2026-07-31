import * as React from "react";

/**
 * A wordless photo answer tile — the heart of every ZilpZalp quiz.
 */
export interface ChoiceTileProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Photo URL of the bird. Falls back to a sand placeholder — always ship a real photo. */
  photo?: string;
  /** Bird name. Shown to grown-ups and read aloud; kids answer from the photo. */
  name?: string;
  /** Photo credit, rendered inside the image, bottom-left, on a warm protection gradient.
   *  Required for CC-BY material, e.g. "Foto: Andrej Chudý (CC BY)". */
  credit?: string;
  /** Rubric colour: tints the tile body, the photo field behind the bird, its border and its ledge. */
  tone?: "papier" | "wald" | "wiese" | "rufe" | "belohnung" | "federn" | "rinde" | "beeren" | "sumpf";
  state?: "idle" | "chosen" | "correct" | "retry";
  /** Tile width in px; height follows. 220 minimum. */
  size?: number;
  /** Fade non-answers after the round is resolved. */
  dimmed?: boolean;
  onSelect?: () => void;
}
export declare function ChoiceTile(props: ChoiceTileProps): JSX.Element;
