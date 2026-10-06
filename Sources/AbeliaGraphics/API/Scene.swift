// points are snapped to a grid with size = 1/8th of a pixel


// struct Scene {
//     var items: []
//     var scenes: [Scene]
// }

// // private
// protocol Geometry {}

// struct SceneItem {
//     var brush: Brush
// }

// enum Brush {
//     case solid(Color)
// }

// private func api() {
//     // noo copyable
//     var scene = Scene()

//     // a class, cache key = (generation, ObjectId)
//     let path = Path()
//         .lineTo()
//         .quadTo()
//         .arcTo()
//         .close()
    
//     // all of these are structs
//     let sdf = Shape.rect(pos, size)
//         .merge(.circle(pos, size), smoothing: 12) // or overload +, - op like pangui
//     // plain struct
//     let brush = ColorBrush()
//     // also plain struct
//     let brush2 = GradientBrush()

//     // must not hold any gpu state. Maybe plain pixel buffer + format + sizing, tiling, 9patch + sampler... 
//     let brush3 = ImageBrush()

//     let pain = BackdropBrush()

//     scene.fill(path, with: brush1)
//     scene.fill(sdf, with: brush2, blend: .overlay) // implicit pass split

//     // no scene.add(otherScene)framebuffer
//     scene.fill(geometry: )

//     scene.drawShadow(Shape.rect(...), shadow param)

//     scene.stroke()
// }
