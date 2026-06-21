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

# UI Layer
basically solidjs with macro generaing an overload to allow reactive binding

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
- basic sdf shadow/border
- Path Renderer
- image ninepatch
- color blend, like backdrop effect, require layer ordering
- hidpi - screen space and framebuffer size wont match
    - `wp_fractional_scale_v1`
    - sdf must be in screenspace
    - so we have viewport space(logical size * dpi), world space(logical size), object space (transform)
- wayland expect a premultiplied gamma-encoded srgb not gamma-encoded srgb premultiplied.
- customizable scaling (down/up) mode
- mipmap?
- `RenderNodeRenderer` render to an any image
- `GradientRegistry` - 1d for now
- `Compositor` schedule multiple `CompositionNode` rendering with `Renderer` 
- DXGI swapchain
- basic compositing + effect layer scheduling
- clip: seem like this require a rasterize into a mask layer for best perf
    - sdf shape
    - CALayer-like mask
    - rect clip is easily computable tho

- query hdr support
    - fuckkkkkkkkkkkkk, out chain
- use `VK_FORMAT_R16G16B16A16_SFLOAT` color texture

