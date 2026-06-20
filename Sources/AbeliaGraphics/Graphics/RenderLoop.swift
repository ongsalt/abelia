import Vulkan

// this is ugly
public final class RenderLoop {
  let context: DeviceContext
  let releaseQueue: ReleaseQueue = ReleaseQueue()

  static let maxFrameInFlightCount = 2
  private var currentFrameInFlightIndex: Int = 0
  var frameResources: [_FrameResource]

  var currentFrameResource: _FrameResource {
    frameResources[currentFrameInFlightIndex]
  }

  public init(context: DeviceContext) throws(Vulkan.Result) {
    self.context = context

    self.frameResources = try (0..<Self.maxFrameInFlightCount).map { i throws(Vulkan.Result) in
      try _FrameResource(index: i, context: context)
    }
  }

  public func waitForAvailableFrameInFlight(reset: Bool = true) throws -> _FrameResource {
    try context.device.waitForFences(
      fences: [currentFrameResource.everythingCompletedFence], waitAll: true,
      timeout: UInt64.max)
    if reset {
      try context.device.resetFences(fences: [currentFrameResource.everythingCompletedFence])
    }

    return currentFrameResource
  }

  // the semaphore returned will be signal when finished rendering
  public func render(
    waiting imageAvailableSemaphore: Semaphore,
    signalling renderFinishedSemaphore: Semaphore,
    commands: GPUCommands
  ) throws {
    self.releaseQueue.flushWithFences(context)

    let res = currentFrameResource
    defer {
      currentFrameInFlightIndex = (currentFrameInFlightIndex + 1) % Self.maxFrameInFlightCount
    }

    try res.commandBuffer.reset()
    try res.commandBuffer.begin()

    commands.apply(to: res.commandBuffer)

    try res.commandBuffer.end()

    let graphicsSubmit = SubmitInfo2(
      waitSemaphoreInfos: [
        .init(
          semaphore: imageAvailableSemaphore, value: 0,
          stageMask: .colorAttachmentOutput, deviceIndex: 0
        )
      ],
      commandBufferInfos: [.init(commandBuffer: res.commandBuffer, deviceMask: 0)],
      signalSemaphoreInfos: [
        .init(
          semaphore: renderFinishedSemaphore, value: 0,
          stageMask: .colorAttachmentOutput, deviceIndex: 0
        )
      ]
      //   } else {
      //     []
      //   }
    )

    try context.graphicsQueue.submit2(
      submits: [graphicsSubmit], fence: res.everythingCompletedFence)
  }
}

public class _FrameResource {
  public let index: Int
  let commandPool: CommandPool
  let commandBuffer: CommandBuffer

  public let imageAvailableSemaphore: Semaphore
  let everythingCompletedFence: Fence

  init(index: Int, context: borrowing DeviceContext) throws(Vulkan.Result) {
    let commandPool = try context.device.createCommandPool(
      .init(flags: .resetCommandBuffer, queueFamilyIndex: context.graphicsFamilyIndex))
    let commandBuffer = try context.device.allocateCommandBuffers(
      .init(commandPool: commandPool, level: .primary, commandBufferCount: 1))

    self.index = index
    self.commandPool = commandPool
    self.commandBuffer = commandBuffer[0]
    self.imageAvailableSemaphore = try context.device.createSemaphore()
    self.everythingCompletedFence = try context.device.createFence(.init(flags: .signaled))
  }
}
