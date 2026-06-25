import Vulkan

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


/// execute immediately, expose a semaphore
public struct GPUFuture<T> {
  let value: T
  let semaphore: Semaphore
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
