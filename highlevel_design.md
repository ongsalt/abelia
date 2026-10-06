# Highlevel design
`AbeliaUI` manage composition and animation now. `AbeliaGraphics` only provide scene descriptor and rendering. `Swinit` and `swift-vulkan` is also nuked


# AbeliaUI
`AbeliaUI` will provide a retained mode traditional widget object like DOM `Element` (that may or may not exposed) but it also provide solidjs-like reactive layer.
- layouting is basically compose/flutters
- might take `Modifier` from compose
- no compositor animation anymore

# AbeliaGraphics

- 4 Coverage provider: SDF, Sparse strips (tile mask) for path, harfbuzz-gpu for text, atlas for whatever
- Clipping
    - Allow arbitrary nested SDF Clipping
    - 1 level of path clipping
- Shadow
    - SDF: allow arbitrary shadow even if everything that is not rounded rect provide incorrect shadow
    - everything else require offscreen pass
- Blend mode
    - simple: just switch pipeline
    - advanced: dynamic rendering localread (no perf benefit on desktop)
- Brush & Effect
    - image brush is positioned relative to canvas
    - BackdropBrush do not require `let backdrop = canvas.sample()` but we might provide this too. Currently its upto the renderer to do pass split
    - Effect is at layer level

## Api
- Canvas with persisted brush/path/effect object
