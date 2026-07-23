# Graphics
expose kinda `windows.ui.composition`-like api. You construct a tree of `Layer` (or `Visual` in WUC term) which will be retained. Most of shape rendered are sdf.

## Drawing Primitive
Sdf shape (+ stroke), analytic shadow, path strip?

Brush: Solid color, Texture (including offscreen texture)

## Path rendering
stolen from vello hybrid ["sparse strips"](https://ethz.ch/content/dam/ethz/special-interest/infk/inst-pls/plf-dam/documents/StudentProjects/MasterTheses/2025-Laurenz-Thesis.pdf)

sort and break path segments into tile. merge them into strip generating 2 kind of quad AA for said strip and Solid for interior area then let the gpu do the rest.

### NOT YET FINALIZED
- break curve into polyline or monotonic quadratic bezier?
    - need to reevaluate when transform change
- compute prepass just for generating coverage texture for aa
    - 1 thread = 1 row in a group, 1 group = 4 row of a strip?
    - rebake once in while when animating transform, rebake again at correct scale once dont 
- fragment: loopblinn?

## Draw ordering
backdrop filter, advanced blend (or anything require reading image below) will force a pass split then pingponging

- need to think about opaque only pass

# Layer API
sdf shape now might emit multiple bounds

## `BaseLayer`
- Pixel snapping
- Is a rect with brush
- Backface visibility
- allow arbtritary clip by just do another shape merging pass like in the shader

## `Layer`
- wont force split composition group (at layer level)
- Multiplicative opacity
- Basic BlendMode
- Expose children `origin`
- Seperate `anchor` in parent space and `transformAnchor`

## `OffscreenLayer`
- Rect+sdf clip, stencil?
- Allow attaching effect graph to entire layer
- so this allow real

## `ShapeLayer` or `CanvasLayer`?
- Expose full sdf primitive
- Force split composition group
- every brush fill in any shape under this will operate at the layer space

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
