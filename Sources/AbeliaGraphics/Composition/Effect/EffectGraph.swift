// import ReactivityGraph

// class EffectGraph {
//   protocol Node {
//     // must report all its children?
//   }

//   class Param<T> {
//     let value: T
//     init(_ value: T) { self.value = value }
//   }

//   enum TextureInput {
//     case source
//     case node(any Node)
//   }

//   class BlurEffect: Node {
//     var radius: Param<Float>
//     let input: TextureInput
//     init(radius: Float, input: TextureInput) {
//       self.radius = Param(radius)
//       self.input = input
//     }
//   }

//   class RefractionEffect: Node {
//     var amount: Float
//     // and a lot of other thing, like sdf?
//     let input: TextureInput
//     init(amount: Float, input: TextureInput) {
//       self.amount = amount
//       self.input = input
//     }
//   }

//   class BlendEffect: Node {
//     var mode: BlendMode
//     let src: TextureInput
//     let dst: TextureInput

//     init(mode: BlendMode, src: TextureInput, dst: TextureInput) {
//       self.mode = mode
//       self.src = src
//       self.dst = dst
//     }
//   }

//   private func api287e687uy() {
//     let blur = BlurEffect(radius: 12, input: .source)
//     let refr = RefractionEffect(amount: 12, input: .node(blur))
//     let blend = BlendEffect(mode: .overlay, src: .node(blur), dst: .node(refr))

//     let brush = EffectBrush(blend)
//     brush[blur.radius]
//     // brush.animate(blur.radius, to: 100)
//   }
// }

// // same first unbounded rule?

// class EffectBrush {
//   let effect: any EffectGraph.Node
//   // param list/map? 
//   // we dont recompile shader, so we can use push constant for each pipeline

//   init(_ effect: any EffectGraph.Node) {
//     self.effect = effect
//   }

//   subscript<T>(_ key: EffectGraph.Param<T>) -> T {
//     // bindable storage?
//     // we need our bindable macro for compositor driven animation
//   }

//   subscript() -> Int {
//     12
//   }
// }
