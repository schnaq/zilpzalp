The listen-again control — every audio quiz has exactly one, centred above the answer tiles.

```jsx
<SoundButton playing={isPlaying} size={180} onClick={replay} />
```

Needs the `zz-ring` keyframe (see `guidelines/motion.css`). Never shrink below 120px; it is the control kids hit most.
