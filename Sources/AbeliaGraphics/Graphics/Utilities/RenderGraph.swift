import Vulkan

// // acyclic directed graph
// class RenderGraph {
//   var nodes: [RenderGraphNode] = []
//   var _nodes: [GPUTask] = []
//   // node's index : [index]
//   var dependencies: [Int: [Int]] = [:]

//   func createNode(_ task: GPUTask, dependencies: [RenderGraphNode] = []) -> RenderGraphNode {
//     let node = RenderGraphNode(task: task, dependencies: dependencies)
//     self.nodes.append(node)
//     return node
//   }

//   func _createNode(_ task: GPUTask, dependencies: [RenderGraphNode] = []) -> IRenderGraphNode<> {
//     self._nodes.append(task)
//     return
//   }

//   func reset() {
//     self.nodes = []
//   }
// }

// protocol IRenderGraphNode<Result>: Identifiable {
//   associatedtype Result
//   var result: Result { get }
// }

// // in our use case, it behave more like a tree
// // TODO: retain + diff this
// class RenderGraphNode: Identifiable {
//   let task: GPUTask
//   let dependencies: [RenderGraphNode]

//   fileprivate init(task: GPUTask, dependencies: [RenderGraphNode]) {
//     self.task = task
//     self.dependencies = dependencies
//   }
// }

// // public for now
public struct GPUTask<Result> {
  public let result: Result
  public let work: GPUCommands
  public let barriers: [ImageMemoryBarrier2]
  public let waitCommands: GPUCommands?
}

extension GPUTask {
  public init(
    yielding result: Result,
    barriers: [ImageMemoryBarrier2] = [],
    work: @escaping (borrowing CommandBuffer) -> Void,
    waitCommands: ((borrowing CommandBuffer) -> Void)? = nil
  ) {
    self.result = result
    self.work = GPUCommands(record: work)
    self.barriers = barriers
    self.waitCommands =
      if let waitCommands {
        GPUCommands(record: waitCommands)
      } else {
        nil
      }
  }
}

public struct GPUCommands: GPUCommandsProtocol {
  let record: (borrowing CommandBuffer) -> Void
  public init(record: @escaping (borrowing CommandBuffer) -> Void) {
    self.record = record
  }

  public func apply(to commandBuffer: borrowing CommandBuffer) {
    record(commandBuffer)
  }
}

public protocol GPUCommandsProtocol {
  func apply(to commandBuffer: borrowing CommandBuffer)
}
