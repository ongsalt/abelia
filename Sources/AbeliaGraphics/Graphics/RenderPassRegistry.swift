/// Passes
/// - main: sdf + brush (need to support gradient sampling mode) + clip, slug?
/// - effect (pingpong, copy -> use as bg, )
///   - blur: require another passes then just sampling from it
///   - refraction
///   - advanced blend 
/// - Arbitrary shadow (force offscreen?)
/// - Gradient {1d, 2d}
/// - Sparse strip (transform + binning is cpu side)
///   - coverage computation 
///   - strip generation
///   - coverage sampling go into main 
/// - [wayland only] Color space resolve
/// 
/// Storages
/// - Main Draw list {type,index}, one shape may contain many border/shadow
///   - Primitive.contents list
///   - Primitive.border: same as fill but onion mode
///   - Primitive.analyticShadow (work only for rounded rect)
/// - Shape list
/// - Polygon Vertex
/// - Gradient stops {1d, 2d}
/// - Sparse strip line list
/// - Effect: tagged union list?
/// 
/// Sampler
/// - nearest, transparent border: for coverage
/// - bilinear, any: for brush


/// Each pass 
/// - may depends on 1 or more result from other pass
/// - requires some kind of input ssbo
/// - emit bindPipeline command, Not begin rendering?
/// So we create main descriptor set once
/// 
/// Each frame
/// - we generate `Pass` from batching
/// - resolve render target needed
/// - the walk the graph again to record commands?
class RenderPassRegistry {

}

// define input, 
struct RenderPassDescription {

}

// every pass share main descriptor set 
protocol RenderPass {
  func execute(resources: inout RenderResources)
  // write its data
  // cmd draw
  // get barrier
}

struct RenderResources {}