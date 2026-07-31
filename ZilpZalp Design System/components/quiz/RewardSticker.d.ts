import * as React from "react";

export interface RewardStickerProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Lucide icon name — used when no photo is given. */
  icon?: string;
  /** Bird photo filling the sticker. */
  photo?: string;
  /** Mandatory credit for CC-BY photos; rendered inside the image, bottom edge. */
  credit?: string;
  label?: string;
  tone?: "sun" | "leaf" | "hoopoe" | "rare";
  /** Not earned yet: sand circle + padlock, still visible. */
  locked?: boolean;
  size?: number;
}
export declare function RewardSticker(props: RewardStickerProps): JSX.Element;
