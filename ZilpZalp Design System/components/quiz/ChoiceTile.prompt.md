The wordless photo answer in a bird quiz — big enough for a 4-year-old, drives all feedback through `state`.

```jsx
<ChoiceTile photo="/assets/photos/wiedehopf.jpg" name="Wiedehopf" credit="Foto: Andrej Chudý (CC BY)" tone="rufe" state="correct" size={280} onSelect={pick} />
```

The locked brand scheme is **E + F**: the tile body is the full rubric colour, the photo field is its lightest tint. Give every tile in a round a different `tone` (`wald`, `rufe`, `federn`, `beeren`, …) — the rubric colour tints body, photo field, border and ledge, which is where the design gets its colour.

States: `idle`, `chosen` (sky ring while the answer is checked), `correct` (leaf, lifts up), `retry` (sun, gentle — never red, never an X). Pair with `dimmed` on the other tiles once resolved. Requires the `zz-pop` keyframe from `guidelines/motion.css` recipes (or any equivalent pop-in).
