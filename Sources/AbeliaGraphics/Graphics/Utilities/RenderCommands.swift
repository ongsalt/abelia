import Vulkan

public struct RenderCommands: RenderCommandsProtocol {
  let record: (borrowing CommandBuffer) -> Void

  public func apply(to commandBuffer: borrowing CommandBuffer) {
    record(commandBuffer)
  }
}

public protocol RenderCommandsProtocol {
  func apply(to commandBuffer: borrowing CommandBuffer)
}
