// import Vulkan

// in our use case, it behave more like a tree
// TODO: retain + diff this
struct RenderGraphNode {
  var work: RenderCommands?
  // TODO: batch barrier
  // var barriers: Barirer
  var waitCommands: RenderCommands?
  var children: [RenderGraphNode] = []
}

