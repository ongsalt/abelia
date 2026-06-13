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

# Flow
- layer was mutated OR requestAnimationFrame 
- tell the renderer we need flush request\
- once it can render -> it will sync main thread, high priority
    - RUN requestAnimationFrame now with `expectedFrameTime` (VK_GOOGLE_display_timing, VK_KHR_present_wait, VK_EXT_present_timing)
    - flush the layer tree
- we are done with main thread, the renderer thread now doing its thing 

# Color
in order to do gradient we must generate an intermediate 1d texture to sample from later on.
2d (mesh) gradient are done by triangluate 

## TODO
- fuckkkkkkkkkkkkk
- use `VK_FORMAT_R32G32B32A32_SFLOAT` color texture

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

# Planning
- copying texture
- gradient
- basic compositing + effect layer scheduling
- 9 grid
- clip
    - sdf shape
    - CALayer-like mask

- use `libharfbuzz-gpu`

