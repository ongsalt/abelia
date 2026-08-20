# Abelia — Current Architecture

This documents what is actually implemented on `new-layer-hierarchy` today, as opposed to
`highlevel_design.md` which is the aspirational design. Where the two disagree, that's called out
explicitly. File paths are relative to `Sources/`.

## 1. Module map

```
CShim, CPlatform, Cnanosvg, CSTBImage, CHarfbuzz   – C targets (Vulkan struct mirror, stb_image, vendor libs)
Reactivity            – OLD reactive core (class-based Signal/Computed/Source/Sink). Not used by AbeliaGraphics.
ReactivityGraph        – CURRENT reactive core (Node/Computed/Bindable). Used by Layer hierarchy and AbeliaUI.
AbeliaGraphics          – the whole compositor: layers, scheduler, Vulkan renderer, shapes, path CPU rasterizer
AbeliaUI                – SwiftUI-like layout/DSL on top of AbeliaGraphics — skeletal, barely started
DSLMacro                – `@freestanding`/result-builder macro support for AbeliaUI (component macro)
LegacyUI                – an older UI experiment; still in the tree but has **no target in Package.swift**,
                          i.e. it does not currently build. Effectively dead code from a prior architecture.
Playground              – the executable that actually exercises AbeliaGraphics (demo scenes, manual testing)
```

`Reactivity` and `ReactivityGraph` are two independent, unrelated reactivity implementations
living side by side; only `ReactivityGraph` is wired into the graphics stack. `Reactivity` appears
to be a first draft that nothing currently depends on outside its own test target.

## 2. Reactivity (`ReactivityGraph`)

A push-pull dependency graph, not signals in the classic sense:

- `Node` (`ReactivityGraph/ReactivityNode.swift`) is the graph vertex. It tracks `dependencies`/
  `dependants` as `Set<Node>`, and a `DirtyFlags` option set (`dirty`, `maybeDirty`). Marking a node
  dirty propagates `maybeDirty` to dependants (lazy propagation — nothing recomputes eagerly).
- `Computed<T>` (`Reactivity` module... — actually `AbeliaGraphics`'s `@Bindable`/`Computed` live in
  `ReactivityGraph`) is a struct-based memoized computation: reading `.value` re-derives only if
  `node.dirty` is non-empty, and `TrackingContext.track { ... }` records which nodes were read
  during recomputation, so the dependency edges are rebuilt every recompute (`clearDependencies()`
  + `addDependency(deps)`).
- `@Bindable` (`ReactivityGraph/Binding.swift`) is the property wrapper layers use for every
  animatable property (`offset`, `size`, `opacity`, `brush`, …). Storage is one of:
  `.const(T)` (plain value, the common case), `.getter(() -> T)`, or `.thunk(Computed<T>)` (reactive
  binding via `layer.$prop.bind { ... }`). This is how `LayoutNode.bindLayerProperties()` in
  AbeliaUI ties a computed layout result to `layer.offset` — but that call site is basically the
  only consumer right now.
- There is no `didSet`-driven scheduling in the reactivity graph itself; `_BaseLayer` glues property
  `didSet` observers directly to `dirtyFlags.insert(...)` (see §3), which is a *separate*,
  coarser dirty-tracking mechanism than the fine-grained reactive graph. The reactive graph is used
  for *derived* values (`accumulatedTransform`, `effectiveOpacity`, `resolvedClip`,
  `contributedClipStack`), not for scheduling re-renders.

## 3. Scene graph: the layer hierarchy

`Composition/Layers/`. Class hierarchy: `_BaseLayer` → `Layer` → `OffscreenLayer`; `ShapeLayer` is a
sibling of `Layer`, inheriting directly from `_BaseLayer`.

### `_BaseLayer`

Holds the geometry/transform state common to everything in the tree:

- `offset: SIMD3<Float>`, `size`, `scale`, `rotation` (+ `rotationAxis` for 3D tilt), `affine`
  (arbitrary extra 4x4), `transformOrigin` (CSS-style pivot for scale/rotation, unit coords),
  `anchor` (in *parent* space, where this layer is pinned), `origin` (offset applied to children).
- Tree plumbing: `parent`, `children`, and a **separate** `offscreenParent`/`offscreenChildren`
  pointer set maintained alongside the real tree — this is what lets the scheduler jump straight to
  "all layers belonging to this composition group" without re-walking from the root (see §4).
- `dirtyFlags: LayerDirtyFlags` (`.transform`, `.draw`, `.compositionGroup`) — set by property
  `didSet`s. Nothing currently *reads* these flags to skip work (no `TODO: cache this` is
  implemented yet in `RenderScheduler`); the pass tree is rebuilt from scratch every frame.
- `clip: LayerClip?` (`.bounds`, `.inset(...)`, `.shape(any ShapeProtocol)`) resolved lazily into
  `resolvedClip: Computed<ClipShape?>` (shape + world transform). `contributedClipStack` is the
  `Computed<ClipStack>` a layer hands its children: it forwards the parent's *same instance*
  unchanged when this layer doesn't clip (so a whole clip-free subtree shares one `ClipStack`
  object, letting the renderer write its GPU program once, keyed by `ObjectIdentifier`). Crossing
  into an `OffscreenLayer` resets the stack to `.empty` — ancestor clips apply to the *composited
  quad* in the parent's pass, not inline to the offscreen subtree's own contents.
- Two transform `Computed`s: `accumulatedTransform` (parent's accumulated ∘ this layer's own
  offset/rotate/scale, pivoting around `transformOrigin`) and `effectiveTransform` (accumulated,
  then re-centered by `anchor` so children compose correctly). `OffscreenLayer` overrides both to
  reset `accumulatedTransform` to `.identity` at its own boundary — an offscreen pass starts a new
  local coordinate space.
- Two opacity `Computed`s: `accumulatedOpacity` (opacity of everything up to and including this
  layer) and `effectiveOpacity` (what a *child* multiplies by). `OffscreenLayer` breaks the opacity
  chain the same way it breaks transform: content inside is *not* pre-multiplied by ancestor
  opacity (that gets applied once, to the composited backdrop quad, in `OffscreenLayer.renderNode`).

### `Layer`

Adds the actually-visible properties: `brush: CompositionBrush?`, `cornerRadius`/`cornerDegree`
(superellipse rounding, see §6), `border: Border?`, `shadow: Shadow?`, `opacity`. `shape` is
overridden to a rounded rect built from `size`/`cornerRadius`/`cornerDegree`.

### `OffscreenLayer`

Subclasses `Layer` purely to reset the transform/opacity chains described above. This is the type
that forces a pass split in the scheduler (§4) — it's the "CompositionGroup" from
`highlevel_design.md`, matching `Visual`'s composition-group semantics in Windows.UI.Composition.
Its effect-graph and additional clip fields are declared in the design doc but not present in code
yet (the class body is currently just the two transform/opacity overrides).

### `ShapeLayer`

The "expose full SDF primitive" layer from the design doc, implemented as planned: an array of
`ShapeItem` (shape + brush + border + shadow + opacity + local offset/rotation/scale), each
becoming its own `RenderNode` inside the parent's composite pass — i.e. it does *not* currently
force its own composition group/pass split despite the design doc saying it should. Every item
still shares the layer's own pass.

### `LayerBuilder`

A `@resultBuilder`-based DSL (`insert { Layer(...); Layer(...) }`) plus convenience
`convenience init`s per layer type. This is the whole "declarative tree construction" story;
there's no diffing/reconciliation — `insert`/`remove` are imperative, called directly by app code
(see `Playground/composition.swift`).

## 4. Frame lifecycle

### Threading model (`Composition/Compositor.swift`)

Two threads, synchronized by a condition variable (`RenderNotifier`):

- **Main thread** owns the `Layer` tree and drives app/animation logic. Mutating any `@Bindable`
  property marks dirty flags but does not itself wake the render thread — `Compositor.onDirty()`
  (called from... nowhere obvious yet; likely meant to be wired to layer mutation, currently mostly
  driven by `requestAnimationFrame`) and `requestAnimationFrame(callback:)` both call
  `notifier.request()`, which signals the condition variable.
- **Render thread** (`Thread` started in `Compositor.init`) loops: block in
  `notifier.shouldRender()` until requested/stopped → apply any pending `SurfaceConfiguration2` →
  `surface.wait()` (CPU-side frame pacing / fence wait) → `surface.acquire()` (swapchain image) →
  **hop back to the main thread synchronously** via `DispatchQueue.main.sync { self.sync() }` to run
  animation-frame callbacks and rebuild the pass tree — → resume on the render thread to record and
  submit the Vulkan command buffer, then blit the composited output into the acquired swapchain
  image and present.
- `Compositor.sync()` is where the two "phases" from the design doc's opening comment
  (`produce pass` / `do its thing`) actually meet: it drains `animationFrameCallbacks`, then calls
  `RenderScheduler.schedule(root:)` to turn the current layer tree into a `Pass` tree (§5). Note the
  comment `// mark layers clean` is unimplemented — dirty flags are never cleared, consistent with
  "no incremental scheduling yet."
- `preRenderFrameCount` (seeded from `surface.frameLatency`) forces the first N frames to render
  unconditionally even with no dirty request, so the swapchain gets primed after resize.
- Present path: render into an internally-owned `RenderTexture` (not the swapchain image directly),
  then explicit `pipelineBarrier2` + `blitImage2` + a second barrier into `finalLayout` before
  `surfaceTexture.present()`. The output texture is deliberately decoupled from the swapchain so
  the renderer never has to know about swapchain image count/format churn.

### `CompositorAnimationController` (`Composition/Animation/`)

A tiny per-compositor pump: `add(_ listener: AnimationFrameUpdatable)` registers a
spring/animation, and as long as the listener list is non-empty it keeps re-requesting animation
frames from the `Compositor` and calling `update(deltaTime:)` on everything, dropping finished
listeners. `SpringAnimator<T>`/`SpringSimulation<T>` (ported from Jetpack Compose) solve the damped
harmonic oscillator in closed form per frame (no substepping needed regardless of `deltaTime`
size) — this is the only animation primitive implemented; there's no keyframe/curve system.

## 5. Scheduling: layer tree → GPU passes

`Composition/Scheduling.swift`. Two-stage compiler from the retained layer tree into a tree of
render passes, run fresh every frame (`RenderScheduler.schedule`):

1. **`CompositionPlanner.plan(root:)`** walks the tree and buckets layers into `CompositionGroup`s,
   splitting at every `OffscreenLayer` boundary (`group.dependencies[layer.id] = <nested group>`).
   This is a flat list per group, not a nested pass structure yet — grouping only, no sizing/overlap
   decisions.
2. **`PassScheduler.schedule(root:)`** walks the `CompositionGroup` tree and produces the actual
   `Pass` tree:
   - Each `CompositionGroup` becomes at least one `Pass` targeting a *new* offscreen `RenderTexture`
     (`PassRenderTarget.new(size:key:canTransfer:)`, keyed by the group root layer's `id` so the
     texture cache — §7 — can reuse it frame over frame without reallocating).
   - Within a group, layers are appended to the **topmost pass they don't conflict with**: if the
     next layer is itself "composite" kind it's just added to the current pass (or, if it's an
     `OffscreenLayer`, its nested group is recursively scheduled first and the *result* is sampled
     back in as a `backdrop`-brush `RenderNode`); if it's some other pass kind that spatially
     overlaps the current pass's contents, a **new pass is forced** and chained as a dependency.
   - `PassRenderTarget` has three cases: `.new` (leaf, allocates/reuses a texture), `.sameAsPrevious`
     (chain onto the same texture — used so a `ShapeLayer`'s items and a following `Layer`'s content
     don't need separate render targets), and `.alternate` (ping-pong buffer keyed the same as
     `.new`, for effects that need to read what they're about to overwrite) — **`.alternate` is
     defined but nothing currently produces it**, since blur/effect layer kinds aren't implemented.
   - **Only `.composite` pass/layer kind exists today.** `LayerKind` also declares `.blur`/`.effect`
     and `Pass`/`PassKind` declare `.effect(regions:)`, but every code path that would produce or
     consume them is commented out, and the `default: fatalError()` / `fatalError("Effect is not
     supported")` branches are what's actually reachable if you tried. `_BaseLayer.kind` is
     hardcoded to always return `.composite` — there is currently no way to construct a layer of any
     other kind.
3. Each `Layer`/`ShapeLayer`/`OffscreenLayer` converts itself to one or more `RenderNode` values
   (`compositeRenderNode`, `shapeItemRenderNodes`, `renderNode(sampling:)` respectively) with clip
   stacks attached (`applying(clip:)`), which is the boundary between "scene graph" and "GPU data"
   (§6/§7).
4. `compositionGroupRootRenderNode()`: when an `OffscreenLayer`/`Layer` acting as a group root has
   its *own* brush, that brush is inlined as a render node directly into the new offscreen texture
   (rather than composited a second time from the parent), so a colored/backdrop `OffscreenLayer`
   doesn't need an extra draw call in the parent pass.

## 6. Shapes: the CPU/GPU SDF algebra

`Common/Shape.swift` + `Resources/{types,sdf_shapes,composite}.slang` + `CShim/include/RenderNode.h`.

- `ShapeProtocol` requires `sdf(_:)`, `contains(_:)`, `bounds`, and — the interesting part —
  `drawInstructions: some Sequence<ShapeMergingInstruction>`. Every shape, however it's built up
  (`Shape.rect(...).union(Shape.circle(...), smoothing:).rounded(...)`), compiles down to a flat
  **postfix program** of three instruction kinds: `.push(ShapeMetadata)` (a primitive shape + its
  local `Transform2D`), `.merge(MergeMode, smoothing:)` (binary op consuming the top two stack
  entries), `.modify(ModifyMode, radius:)` (unary op on the top-of-stack, in place). `MergedShape`,
  `TransformedShape`, `ModifiedShape` are all `struct`s composing `drawInstructions` lazily
  (`.chain(...)`/`.lazy.map`) — no shape ever allocates an intermediate representation on the Swift
  side beyond the final flattened sequence written to the GPU buffer.
- The CPU (`Shape.sdf`) and GPU (`sdf_shapes.slang`) implementations are two independent hand-ported
  copies of the same iq distance functions (rect/superellipse, arc, pie, ellipse, regular polygons
  pentagon/hexagon/octagon/hexagram/pentagram, quadratic-circle superellipse, arbitrary polygon).
  The CPU copy exists so shapes can answer `contains(_:)` (hit-testing) without a GPU round-trip;
  it is *not* used for rendering.
- `Transform2D` (distinct from the layer's 4x4 `Affine`) is the 2D affine baked into each `push`
  instruction. Its `.gpu` property produces the **inverse** linear part (world→shape-local) plus a
  conservative `distanceScale` (min of the two axis scales) — since SDF distances are only exactly
  correct under uniform scale, this is the approximation used to keep a single distance field
  meaningful after non-uniform transforms.
- **GPU side is a stack machine**, not a tree walk: `sdfMerge` in `composite.slang` iterates the
  flat instruction buffer with a fixed `STACK_SIZE = 16` local array, doing exactly what the Swift
  postfix program encodes. `Renderer.writeRenderNode` (`Graphics/Renderer.swift`) is what actually
  serializes a Swift `ShapeMergingInstruction` sequence into `CShim.ShapeMergingEntry` GPU structs
  in `shapeGroupStorage`, patching in a real buffer offset for `.polygon` shapes (whose vertices
  live in a *separate* `polygonVertexStorage` SSBO, since they're variable-length).
- **Clips reuse the exact same machinery**: a `ClipStack`'s shapes are also flattened into the shape
  buffer as a push...push...intersect program (`ClipRunCache` in `Renderer`, keyed by
  `ObjectIdentifier(ClipStack)` so a stack shared by many sibling `RenderNode`s is written once per
  frame) and evaluated by the fragment shader's `clipCoverage()`, which maps the fragment into
  world space and calls the same `sdfMerge`.
- Struct layouts are hand-kept byte-identical across three representations: Swift (`RenderNode.swift`,
  `Common/Shape.swift`), C (`CShim/include/RenderNode.h`, used for the actual GPU buffer memory
  layout from the Swift side via `CShim.RenderNode` etc.), and slang (`types.slang`). Comments in
  `types.slang` (e.g. `Layout: kind(4) + ...`) are the source of truth for keeping std430 packing
  aligned with the C struct — there is no automatic codegen tying these three together.

## 7. Brushes, textures, and backdrop compositing

- Public API is `CompositionBrush` (`Composition/CompositionBrush.swift`): `.solid(Color,
  blendMode:)` or `.texture(any CompositionTexture, fillMode:, crop:, nineSlices:)`.
  `BlendMode` only has `.normal`/`.overlay` declared and isn't consumed anywhere in the shader yet.
  This lowers to the internal `Brush` (`Common/Brush.swift`), which additionally has `.backdrop(key:
  crop:)` — not constructible by app code, only produced internally by
  `OffscreenLayer.renderNode(sampling:)` to reference another pass's *not-yet-resolved* texture by
  its scheduler `key` (an `Int`, the owning layer's `id`).
- `Renderer.resolveBackdropBrush` is the one place `.backdrop` gets turned into a real
  `.texture(index:)` right before writing the GPU `RenderNode`, looking the texture up from
  `TextureCache` by key and re-cropping for the texture's actual over-allocated capacity vs logical
  size (`croppedSizeMultiplier`).
- `RenderTexture`/`TextureRegistry` (`Graphics/RenderTexture.swift`): textures live in one big
  bindless `Texture2D[]` array (`updateAfterBind`/`partiallyBound`, 512Ki slots declared, matching
  the `sdf_shapes`/`composite.slang` `[[vk::binding(0,1)]] Texture2D[] textures` + `NonUniformResourceIndex`
  reads). `getRenderTexture(size:)` first tries to reuse an available texture whose *capacity* fits
  (over-allocated by 1.2x on creation, `willResize: true`), falling back to allocating a new one and
  registering it into the descriptor array — textures are never deleted mid-session, only recycled
  into `availableTextures`. `TextureCache` (keyed by the owning layer's `id`, i.e. the scheduler
  `key`) is what makes a `CompositionGroup`'s render target persist frame-to-frame instead of being
  reallocated; `CompositeGroupTextures.main`/`.alternate` exist for future ping-pong effects but
  `.alternate` is currently never populated (no effect pass produces `.alternate` targets — see §5).
- Gradients: the public builder API exists (`gradient { Color.red.at(0.0) ... }`,
  `ColorStopBuilder`, `ColorStop<Position>`) and there's a dedicated `gradient.slang` vertex/fragment
  shader plus a whole `color.slang` module of color-space math (sRGB↔linear, OKLCH→OKLab→linear
  sRGB, linear-sRGB↔linear-P3) sitting ready to use — but `GradientRenderer.get()` is a literal
  `fatalError("unimplemented")` and nothing calls into `gradient.slang`. Gradients are not usable
  today despite `BrushKind.gradient1d` already existing as a reserved enum case everywhere.
- `EffectGraph` (`Composition/Effect/EffectGraph.swift`) is *entirely* commented out except for two
  empty marker protocols (`CompositionEffect`, `EffectSource`) and one uncalled `BlurEffect` class.
  The node-graph API sketched in the design doc (`BlurEffect`/`RefractionEffect`/`BlendEffect` +
  `EffectBrush` subscripting into a param) exists only as commented-out code — a design draft, not
  a partial implementation.

## 8. Vulkan renderer

`Graphics/{Context,Pipelines,Renderer,RenderLoop,RenderTexture,Surface2,GPUBuffer,ImageUploader}.swift`.

- **One graphics pipeline for everything** (`Pipelines.swift`): `compositionPipeline`, dynamic
  rendering (no render passes/framebuffers), `synchronization2`, descriptor indexing
  (`shaderSampledImageArrayNonUniformIndexing`, `descriptorBindingPartiallyBound`, etc. required as
  Vulkan 1.2/1.3 device features in `Context.swift`). No vertex buffers at all — the vertex shader
  synthesizes a fullscreen(-ish) quad per instance from `g_Positions`/`uv_positions` constant
  arrays plus the `RenderNode`'s own bounds, expanded by antialiasing padding (`+2px`) and, for
  shadow draws, by `shadowSpread + shadowBlur`.
  - Descriptor set 0 (`mainDescriptorSetLayout`, one instance per frame-in-flight via
    `RendererFrameResource`): binding 0 `RenderNode[]`, 1 `ShapeMergingEntry[]`, 2 `DrawListItem[]`,
    3/4 reserved for blur/effect region storage (declared, unused), 5 `float2[]` polygon vertices.
  - Descriptor set 1: the bindless texture array (`textureDescriptorSetLayout`, shared globally,
    not per-frame).
  - Descriptor set 2: a single global bilinear/clamp-to-edge sampler.
  - Push constant: one `float4x4` orthographic-ish projection (built directly in
    `Renderer.render`, not `Pipelines`) mapping pass-pixel-space to NDC.
- **Draw submission**: `render(nodes:to:...)` writes every `RenderNode` for the pass into the
  per-frame storage buffers (`writeRenderNode`, §6), then issues **one** `cmd.draw(vertexCount: 6,
  instanceCount: renderNodeCount, ...)` — each of fill/stroke/shadow is a separate `DrawListItem`
  (`{index into RenderNodeBuffer, drawMode}`) rather than a separate draw call, so a single node
  with a border and a shadow contributes 3 instances, but there's still exactly one `vkCmdDraw` per
  pass. Blend state is fixed straight-alpha-over (`one, oneMinusSrcAlpha`) premultiplied in-shader.
- **Pass execution** (`Renderer.walk`, recursive over `Pass.dependencies`): before rendering a pass,
  every dependency's output texture gets an explicit `renderTarget → sampling` layout barrier, then
  the pass's own target gets a barrier into `attachmentOptimal` (with special-casing so
  `.sameAsPrevious` doesn't re-transition a texture that's already the active render target). This
  is fully manual synchronization2 barrier bookkeeping — no render-graph abstraction beyond the
  handwritten `walk`.
- **Frame pacing** (`RenderLoop.swift`): `maxFrameInFlightCount` command buffers/pools, each frame
  writes GPU timestamp queries (`timeQueryPool`, 64 slots, wrapped via `% 32`) so
  `getLatestAvailableFrameTime()` can report ms/FPS (`Log.verbose(.compositor, ...)` in
  `Compositor`'s render loop). `submit()` builds a `SubmitInfo2` with an optional platform
  `timeline` semaphore triple (used by the DXGI path) alongside the ordinary binary
  acquire/render-finished semaphores (used by the Vulkan-WSI path).
- **`Surface2` abstraction**: one protocol, two implemented backends, both gated by `#if os(Windows)`/
  Linux at compile time. `VulkanWSISurface` (Linux/Wayland) does swapchain (re)creation with a 1.2x
  oversized allocation the same way textures are (`configure`), deferred destruction of the
  *previous* swapchain/views/semaphores via `ReleaseQueue.schedule(in: frameInFlight + 1)` so
  in-flight frames referencing the old swapchain aren't invalidated early. `DXGISurface`
  (`DXGISurface.swift`, Windows-only) is a real, non-trivial implementation, not a stub: it imports
  D3D12-allocated swapchain images into Vulkan as external memory (`ImportMemoryWin32HandleInfoKHR`
  / `MemoryDedicatedAllocateInfo`), synchronizes the two APIs with an imported D3D12-fence-backed
  Vulkan timeline semaphore (`Surface2.timeline`, used instead of the binary acquire/render-finished
  semaphores the Vulkan-WSI path uses), and hands the actual presentation off to a native
  `d3d12_presenter_*` C++ helper (`CPlatform/win32/d3d12_presenter.{hpp,cpp}`, ~290 lines, plus a C
  shim) that owns the DXGI swapchain/present call itself. It supports resize
  (`d3d12_presenter_resize` + reimporting the new images) but the comment `// TODO: resize path` on
  `configure()` suggests that path is still being hardened. Since it's behind `#if os(Windows)`, none
  of this is visible or exercised when building/reading the repo on Linux.
- **`ReleaseQueue`**: two deferred-destruction mechanisms in one class — `schedule(in: n)` (run
  after `n` more `flush()` calls, i.e. N frames from now — used for swapchain teardown) and
  `schedule(after: fence)` (run once a specific fence signals, non-blocking poll via
  `waitForFences(timeout: 0)` — used for staging-buffer cleanup after `ImageUploader`'s one-shot
  upload).
- **`ImageUploader`** (`loadImage(filename:)`): fully synchronous-submit staging upload using
  `stb_image` (`CSTBImage`) — allocates a host-visible staging buffer, `memcpy`s decoded pixels,
  records a one-time command buffer, submits with its own fence, and schedules staging-buffer
  cleanup on that fence. Not integrated with the frame loop's `ReleaseQueue`/timeline; it's a
  blocking-ish helper meant for "load an image asset up front," not a streaming asset pipeline.

## 9. Path rendering (CPU) — unrelated to the SDF pipeline, and not yet connected to the GPU

`Path/{Path,PathRasterization,Path+SVG}.swift`. This is a completely separate code path from the
SDF/`RenderNode` machinery above — it exists to rasterize arbitrary vector paths (beziers) to a CPU
pixel buffer, presumably as groundwork for text glyph rendering (per the readme's "text hates you"
note) or SVG import, neither of which is wired up yet:

- `Path` stores segments already resolved (each carries its own start point, so subpath boundaries
  are just discontinuities — no `moveTo` command replay needed). `QuadraticBezierCurve`/
  `CubicBezierCurve` flatten either uniformly or via tolerance-driven recursive de Casteljau
  subdivision (`isFlat` compares the control-point-to-chord distance against `tolerance`, capped at
  `maxSubdivisionDepth = 20` to bound cusp cases).
- `fillScanline` is a from-scratch analytic (trapezoidal) scanline rasterizer: for each pixel row it
  builds active-edge tables bucketed by start/end Y, accumulates fractional coverage per pixel via
  signed trapezoid area, resolves nonzero/even-odd winding, and blends **in linear light** (decoding
  sRGB destination bytes through a 256-entry LUT, compositing premultiplied, re-encoding) — notably
  more careful about color-space correctness than a naive scanline fill, callable independent of any
  Vulkan state (pure CPU, `MutableSpan<Pixel>` in, no GPU dependency at all).
- This module has no caller anywhere in `Playground` or elsewhere in the tree right now — it is
  implemented and (per its structure) presumably tested, but currently dormant infrastructure.
- `highlevel_design.md`'s "sparse strips" GPU path renderer (tile/strip binning, coverage prepass,
  loop-blinn fragment) described under **Path rendering** is **not implemented at all** — no code
  in the repo does GPU tile-based path coverage. The CPU scanline rasterizer above is the only path
  rasterizer that exists, and it's a different algorithm entirely (not sparse strips).

## 10. Text

`Text/Text.swift` is a comment-only stub (five bullet points: load font, measure/break lines, shape
via Harfbuzz, write glyphs to a texel buffer, sample in shader). `CHarfbuzz` is vendored and has a
Package.swift target, so the dependency is *available*, but zero Swift code calls into it. Text
rendering does not exist yet in any form (no font loading, no shaping, no glyph atlas, no draw
path).

## 11. AbeliaUI / DSLMacro / LegacyUI — adjacent, mostly unbuilt-out

- **AbeliaUI** (`Node/Node.swift`, `Runtime.swift`, `Layout/Size.swift`): a `Node`/`LayoutNode` class
  pair exists (`LayoutNode` owns one `Layer` and can `@Bindable`-bind its `offset` to a computed
  layout result), and a `Size` enum sketches a Clay/CSS-flex-inspired sizing model (`.fit`,
  `.fixed`, `.fraction`, `.flex(weight:basis:shrink:)`, `.ratio`) — but it's all comments and no
  actual flex-layout algorithm is implemented. `Runtime` is an `EventLoopDelegate` with every
  callback empty. This module does not do anything usable yet.
- **DSLMacro**: a `SwiftSyntax`-based macro target (`@attached(member)`/`extension` machinery for
  things like the `@OptionSet` macro used by `ReactivityGraph`'s `DirtyFlags`) plus a `Component`
  macro presumably meant for AbeliaUI's future component model. Supporting infrastructure, not a
  user-facing feature by itself.
- **LegacyUI**: a fuller SwiftUI-style DSL (view builders, modifiers, a `LayoutNode`/reactive
  bindings/template-effect system, its own `Application`/`GraphicsAPI+Platforms` glue) — but **it
  has no target in `Package.swift`**, so it is not part of the current build at all. It reads as
  the previous generation of the UI layer, superseded by (the still-nascent) `AbeliaUI`, left in the
  tree but orphaned.
- **`Playground`** is the only thing that actually exercises `AbeliaGraphics` end to end today
  (`composition.swift`/`main.swift`/`ui.swift`): it builds `Layer`/`OffscreenLayer`/`ShapeLayer`
  trees by hand (no AbeliaUI/DSLMacro involved), demonstrates the clip stack, opacity groups,
  texture brushes, borders/shadows, SDF shape merges, and drives a `SpringAnimator` off cursor
  input. This is the closest thing to a spec for "how the public API is meant to be used" right now.

## 12. Summary: implemented vs. stubbed

| Area | State |
|---|---|
| Layer tree, transforms, opacity/clip accumulation | Implemented |
| SDF shape algebra (primitives, union/intersect/xor/subtract/onion/round, arbitrary affine) | Implemented, CPU+GPU |
| Composition groups / offscreen passes / backdrop sampling | Implemented |
| Solid + plain texture brushes, 9-slice/crop/tile fields | Implemented (tile/9-slice UV math still TODO in shader) |
| Borders (onion stroke), box shadow | Implemented (shadow is an approximation — `pow` falloff, not erf, per its own TODO) |
| Blur / arbitrary effect graph / backdrop filters | **Not implemented** — commented out, unreachable `fatalError` paths |
| Gradients | **Not implemented** — API + shader shell exist, `GradientRenderer.get()` fatalErrors |
| Text | **Not implemented** — comment-only stub |
| GPU sparse-strip path rendering (per design doc) | **Not implemented** — a different, CPU-only scanline rasterizer exists instead, and is unused |
| Vulkan/Wayland backend | Implemented |
| DXGI/Windows backend | Implemented (D3D12↔Vulkan interop + native presenter); untested from this Linux checkout, resize path marked TODO |
| Spring animation | Implemented |
| AbeliaUI (layout DSL) | Barely started — data types sketched, no algorithm |
| LegacyUI | Dead code — not in the build |
