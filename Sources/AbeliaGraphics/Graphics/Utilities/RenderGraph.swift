import Vulkan

// in our use case, it behave more like a tree
// TODO: retain + diff this
struct RenderGraphNode {
  // lazy even in the gpu side
  var work: () -> RenderCommands
  // TODO: batch barrier
  // var barriers: Barirer
  var waitCommands: (() -> RenderCommands)?
  var children: [RenderGraphNode] = []
}

// public for now
public struct RenderTask {
  public var work: RenderCommands
  /// 
  public var barriers: [ImageMemoryBarrier2] = []
  public var waitCommands: RenderCommands? = nil
}

extension RenderTask {
  public init(barriers: [ImageMemoryBarrier2] = [], work: @escaping (borrowing CommandBuffer) -> Void, waitCommands: ((borrowing CommandBuffer) -> Void)? = nil) {
    self.work = RenderCommands(record: work)
    if let waitCommands {
      self.waitCommands = RenderCommands(record: waitCommands)
    }
  }
}

