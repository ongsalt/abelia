import CVulkan

@MainActor
func createBatches(
  dirtyLayers: borrowing [Layer],
  root: Layer
) -> [Batch] {
  // if we dont have any child with isEffect fine
  // TODO: support rasterization roots
  let (children, roots) = childrenWithoutRasterizationRootChildren(of: root)

  return [Batch(rasterizationRoot: root, subpasses: [Subpass(dependencies: [], inner: .composite(children))])]
}

@MainActor
func childrenWithoutRasterizationRootChildren(of layer: Layer) -> (children: [Layer], rasterizationRoots: [Layer]) {
  var children: [Layer] = []
  var roots: [Layer] = []
  for c in layer.children {
    if !layer.isRasterizationRoot {
      let (children2, _) = childrenWithoutRasterizationRootChildren(of: c)
      children += children2
    } else {
      roots.append(layer)
    }
    children.append(c)
  }

  return (children, roots)
}



struct Batch {
  let rasterizationRoot: Layer
  let subpasses: [Subpass]
}

extension Batch {
  // init(for layer: Layer, childrenWithoutRasterizationRootChildren: [Layer]) {

  // }

  // func writeCommand() {

  // }
}

// 
struct Subpass {
  let dependencies: [Layer] // only raster root
  let inner: SubpassType
}

enum SubpassType {
  case effect([EffectRegion])
  case composite([Layer])
}

struct EffectRegion {
  let effect: ImageFilter
  // let shape: Shape // sdf font is also fine
  let position: Position<Float>
  let size: Size<Float>
}

extension Layer {
  fileprivate var isEffect: Bool {
    self.brush?.isEffect ?? false
  } 
}