import Vulkan

struct RenderCommands: RenderCommandsProtocol {
  let record: (borrowing CommandBuffer) -> Void

  func apply(to commandBuffer: borrowing CommandBuffer) {
    record(commandBuffer)
  }
}

protocol RenderCommandsProtocol {
  func apply(to commandBuffer: borrowing CommandBuffer)
}
