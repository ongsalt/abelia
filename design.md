# Graphics Layer

## `Primitive`
map one to one so shader input. (conceptually, actually it gonna be in storage buffer). It contains
- transformation matrix
- shape `Shape` (sdf based): only rounded rect for now 
- brush: solid, 1dgradient, texture, backdrop (do not exist at shader level)
- border: brush, style?, width
- shadow? (gonna produce another quad?)
- merge params: smoothFactor, [lenght at head, combinationMode elsewhere]

## ShapeProtocol
is a `Shape` OR a merged `Shape` 


## `Layer` 
control composition + render ordering, merging multiple layer into 1 draw call. each layer contains 1 backing `Primitive`. This `Primitive` wont be rasterized in its own layer when `shouldRasterize` is true 

Clipping is at `Layer` level. allowing
- sdf shape clip
- 

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

- TODO: detect `Module::Prop` and `Module.Prop`

component boundary do not exist as we cant really transform function content. So every lifecycle stuff need to be tied to parent element scope.

# Planning
- basic compositing + effect layer scheduling
- 9 grid
- clip
    - simple rect
    - sdf shape
    - CALayer-like mask

- remove blend2d
- use `libharfbuzz-gpu`
