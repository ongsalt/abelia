// this is ugly

import Vulkan

public final class RenderLoop {
  let context: DeviceContext
  let releaseQueue: ReleaseQueue = ReleaseQueue()

  let timeQueryPool: QueryPool

  var maxFrameInFlightCount: Int
  private var currentFrameInFlightIndex: Int = 0
  var frameResources: [FrameResource]
  var currentFrameIndex: UInt32 = 0
  let timestampPeriod: Float

  var currentFrameResource: FrameResource {
    frameResources[currentFrameInFlightIndex]
  }

  public init(context: DeviceContext, maxFrameInFlightCount: Int) throws(Vulkan.Result) {
    self.maxFrameInFlightCount = maxFrameInFlightCount
    self.context = context

    self.frameResources = try (0..<maxFrameInFlightCount).map { i throws(Vulkan.Result) in
      try FrameResource(index: i, context: context)
    }

    self.timeQueryPool = try context.device.createQueryPool(
      QueryPoolCreateInfo(
        queryType: .timestamp,
        queryCount: 64,
      )
    )
    self.timeQueryPool.reset(firstQuery: 0, queryCount: 64)
    self.timestampPeriod = context.physicalDevice.getProperties().limits.timestampPeriod
  }

  // the semaphore returned will be signal when finished rendering
  public func submit(
    commands: GPUCommands,
    waiting imageAvailableSemaphore: Semaphore?,
    signalling renderFinishedSemaphore: Semaphore?,
    signallingFence fence: Fence?,
    timeline: (Semaphore, imageAvailable: UInt64, renderFinished: UInt64)? = nil
  ) throws {
    self.releaseQueue.flushWithFences(context)

    let res = currentFrameResource
    defer {
      currentFrameInFlightIndex = (currentFrameInFlightIndex + 1) % maxFrameInFlightCount
    }

    try res.commandBuffer.reset()
    try res.commandBuffer.begin()

    // run animation frame

    res.commandBuffer.resetQueryPool(
      queryPool: timeQueryPool, firstQuery: (currentFrameIndex % 32) * 2, queryCount: 2)
    res.commandBuffer.writeTimestamp2(
      stage: .topOfPipe, queryPool: timeQueryPool, query: (currentFrameIndex % 32) * 2)
    commands.apply(to: res.commandBuffer)
    res.commandBuffer.writeTimestamp2(
      stage: .bottomOfPipe, queryPool: timeQueryPool, query: (currentFrameIndex % 32) * 2 + 1)

    try res.commandBuffer.end()

    var waitSemaphoreInfos: [SemaphoreSubmitInfo] = []
    if let imageAvailableSemaphore {
      waitSemaphoreInfos.append(
        SemaphoreSubmitInfo(
          semaphore: imageAvailableSemaphore, value: 0,
          stageMask: .colorAttachmentOutput, deviceIndex: 0
        ))
    }

    var signalSemaphoreInfos: [SemaphoreSubmitInfo] = []
    if let renderFinishedSemaphore {
      signalSemaphoreInfos.append(
        SemaphoreSubmitInfo(
          semaphore: renderFinishedSemaphore, value: 0,
          stageMask: .colorAttachmentOutput, deviceIndex: 0
        )
      )
    }

    if let (timelineSemaphore, imageAvailable, renderFinished) = timeline {
      waitSemaphoreInfos.append(
        SemaphoreSubmitInfo(
          semaphore: timelineSemaphore, value: imageAvailable,
          stageMask: .allCommands, deviceIndex: 0
        )
      )

      signalSemaphoreInfos.append(
        SemaphoreSubmitInfo(
          semaphore: timelineSemaphore, value: renderFinished,
          stageMask: .allCommands, deviceIndex: 0
        )
      )
    }

    let graphicsSubmit = SubmitInfo2(
      waitSemaphoreInfos: waitSemaphoreInfos,
      commandBufferInfos: [.init(commandBuffer: res.commandBuffer, deviceMask: 0)],
      signalSemaphoreInfos: signalSemaphoreInfos
    )

    currentFrameIndex += 1
    try context.graphicsQueue.submit2(
      submits: [graphicsSubmit],
      fence: fence,
    )
  }

  func updateFrameInFlightCount(_ count: Int) {
    let prev = self.maxFrameInFlightCount
    if count > prev {
      for i in prev..<count {
        try! frameResources.append(FrameResource(index: i, context: context))
      }
    }

    self.maxFrameInFlightCount = count

  }

  func getFrameTime(index: UInt32) throws -> Double {
    var timestamps: [2 of UInt64] = [0, 0]
    try timeQueryPool.getResults(
      firstQuery: index * 2,
      queryCount: 2,
      dataSize: MemoryLayout<[2 of UInt64]>.size,
      data: &timestamps,
      stride: UInt64(MemoryLayout<UInt64>.size),
      flags: .type64
    )

    let timeMs = (Double(timestamps[1]) - Double(timestamps[0])) * Double(timestampPeriod) / 1e6
    return timeMs
  }

  func getLatestAvailableFrameTime() throws -> Double? {
    if currentFrameIndex < UInt32(maxFrameInFlightCount) {
      return nil
    }
    let index: Int = (Int(currentFrameIndex) - maxFrameInFlightCount) % 32
    return try getFrameTime(index: UInt32(index))
  }
}
public class FrameResource {
  public let index: Int
  let commandPool: CommandPool
  let commandBuffer: CommandBuffer

  init(index: Int, context: borrowing DeviceContext) throws(Vulkan.Result) {
    let commandPool = try context.device.createCommandPool(
      .init(flags: .resetCommandBuffer, queueFamilyIndex: context.graphicsFamilyIndex))
    let commandBuffer = try context.device.allocateCommandBuffers(
      .init(commandPool: commandPool, level: .primary, commandBufferCount: 1))

    self.index = index
    self.commandPool = commandPool
    self.commandBuffer = commandBuffer[0]
  }
}
