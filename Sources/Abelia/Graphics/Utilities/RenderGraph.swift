// import Vulkan

// in our use case, it behave more like a tree
// TODO: retain + diff this
final class RenderGraphNode {
  private(set) var work: RenderCommands?
  // TODO: batch barrier
  // private(set) var barriers: Barirer
  private(set) var waitCommands: RenderCommands?

  var children: [RenderGraphNode] = []
}
