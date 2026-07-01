# Graphics Layer

## `Primitive`
map one to one so shader input. (conceptually, actually it gonna be in storage buffer). It contains
- transformation matrix
- shape `Shape` (sdf based): only rounded rect for now 
- mergeInstruction: in case of merging multiple shape, Int32 negative if none 
- brush: solid, 1dgradient, texture, backdrop (do not exist at shader level)
- border: brush, style?, width
- shadow? (gonna produce another quad?)

## MergeInstruction
shape+mergeOp tagged union instruction list in postfix order

## Shader input
- nodes (aka. Primitive list) : .storageBuffer
- mergeInstrcutions : .storageBuffer
- textures needed

## `Layer` 
control composition + render ordering, merging multiple layer into 1 draw call. each layer contains 1 backing `Primitive`. This `Primitive` wont be rasterized in its own layer when `shouldRasterize` is true 

Clipping is at `Layer` level. allowing sdf shape clip OR alpha mask form another layer (later)

## RenderPass and Layer Grouping 

Walk the layer tree to update each `RenderNode` accumulated affine.
    - reset when the node force an offscreen pass
    - also add some texture local offset (push constants: viewMatrix?)

Walk the tree again to produce `RenderPass`es.

Each pass must not be able to batch with each other (so it must already be most optimal grouping)

### EffectPass 
- must not contains an overlapping rect
- require 1 fullsize intermediate texture (may dup, to reduce pipeline deps/block)
- skippable when each region deps are not not dirty???, so we need dirty rect

### BlurPass
- Same as effect pass
- require n intermediate texture per pass (pre allocate 10, at 1/4^i size so ~1/3 maxSize)

### CompositePass 
- must not contains inner node with opacity in (0, 1)
- may require intermediate texture
- may contains deps (its children that require an offscreen pass)
- skippable when
- have 2 variant, one with normal rop, other with fragment_shader_interlock for custom blending
    - VK_EXT_fragment_shader_interlock 
        - guarantee fragment shader invocation order
        - good enough on desktop (80% ish)
    - VK_EXT_shader_tile_image
        - better android support (30%). NO QUALCOMM, fuck
    - VK_EXT_rasterization_order_attachment_access
        - 25%
    - VK_KHR_dynamic_rendering_local_read

    - https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/framebuffer-fetch-in-vulkan

every offscreen holder must aggressively cache its content

This would yield a rendergraph (but this one is certainly a tree)

CompositeGroup can have children (its deps). we can represent this with just list not tree, cuz its children always render to seperate texture. just prepend it children. and at barrier before parent.


## Flow
- layer was mutated OR requestAnimationFrame 
- tell the renderer we need flush request\
- once it can render -> it will sync main thread, high priority
    - RUN requestAnimationFrame now with `expectedFrameTime` (VK_GOOGLE_display_timing, VK_KHR_present_wait, VK_EXT_present_timing)
    - flush the layer tree
- we are done with main thread, the renderer thread now doing its thing 

## Color
in order to do gradient we must generate an intermediate 1d texture to sample from later on.
2d (mesh) gradient are done by triangluate 

## Texture management
- texture atlas
- font
    - im not doing this myself.
    - or maybe directwrite on windows, pango on linux
    - `libharfbuzz-gpu` ?
- blur/effect texture: 2 per rasterizationRoot (pingponging)
    - refraction require sdf function to return a vector back instead?


# Composition
- expose layer tree
    - Layer (with blendMode)
    - EffectLayer
    - ShapeLayer

- scheduling is per root, layer with dependency will force a barrier
    - effect layer force an effect pass, which can be batched

## Flow
- layer is dirty
- start draw loop
- wait until fif is available (it will call us back)
- we compute accumulated transform (linearly)
    - only for dirty node
- record draw command
    - sorting layer
    - no optimization for now
    - only dirty node + root
- renderthread will pull next frame too, will stop pulling once
    - there is no animation frame
    - not dirty


# UI Layer
basically solidjs with macro generaing an overload to allow reactive binding

ui node is just a layer + `YGNode`

```swift
@Component
func Text(_ text: Prop<some StringProtocol>) -> View {
    Effect {
        print(text.value)
    }
}
```

will generate

```swift
func Text(_ text: @autoclosure @escaping () -> some StringProtocol) -> View {
    Text(Prop(getter: text))
}
```

- TODO: detect `Reactivity::Prop` and `Reactivity.Prop`

component boundary do not exist as we cant really transform function content. So every lifecycle stuff need to be tied to parent element scope.

# TODO

## Fix
- COMPUTE SHADOW IN LOCAL COMPOSITION GROUP
- tell wayland that surface is cropped, setOpaqueRegion or something

## the rest
- animation frame
- clipping
- shapes layer (retained)
- better image filing api
    - fill/stretch
    - crop
    - ninepatch
- optimize `arc` bounding box
- bring back blend2d

- hidpi - screen space and framebuffer size wont match
    - `wp_fractional_scale_v1`
    - sdf must be in world space
- wayland expect a premultiplied gamma-encoded srgb not gamma-encoded srgb premultiplied.
- `GradientRegistry` - 1d for now
- DXGI swapchain
- CALayer-like mask
- fastpath for rect mask

- query hdr support
    - fuckkkkkkkkkkkkk, out chain
- use `VK_FORMAT_R16G16B16A16_SFLOAT` color texture

- Path Rendering

