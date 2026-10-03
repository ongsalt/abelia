# Highlevel design
`AbeliaUI` manage composition and animation now. `AbeliaGraphics` only provide scene descriptor and rendering. `Swinit` and `swift-vulkan` is also nuked


# AbeliaUI
`AbeliaUI` will provide a retained mode traditional widget object like DOM `Element` (that may or may not exposed) but it also provide solidjs-like reactive layer.
- layouting is basically compose
- might take `Modifier` from compose

# AbeliaGraphics

- 3 Coverage provider: SDF, Sparse strips for path, harfbuzz-gpu for text
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
    - image brush is positioned relative to Layer
    - BackdropEffect
    - Effect is at layer level


## Path rendering
stolen from vello hybrid ["sparse strips"](https://ethz.ch/content/dam/ethz/special-interest/infk/inst-pls/plf-dam/documents/StudentProjects/MasterTheses/2025-Laurenz-Thesis.pdf)

sort and break path segments into tile. merge them into strip generating 2 kind of quad AA for said strip and Solid for interior area then let the gpu do the rest.

## Draw ordering
backdrop filter, advanced blend (or anything require reading image below) will force a pass split then pingponging

- need to think about opaque only pass

# Brush API
- solid color is solid color
- 1d gradient need a compute prepass to interpolate the color
- image brush with scaling option operate in Layer local space
    - none: bascially chowder effect with layer origin as brush origin
- Backdrop brush -> Force pass split within a `OffscreenLayer` boundary (aka `CompositionGroup`)
- effect brush: like blend(src, dst), blur, refraction

# Effect API
an effect graph, also stolen from wuc
- graph can generate a brush
- each node need to propagate its bounds (and dirty region?)

# Shape API
- sdf from https://iquilezles.org/articles/distfunctions2d/
- allow unary ops: `onion, round`, binary ops: `union, intersect, xor, subtract` with smoothing. All operate in a per shape local space.

# Threading
- rewrite getter Bindable + maintain getter list, per compositor
- pull diff on frame 