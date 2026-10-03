import Vulkan

class ReleaseQueue {
  private var currentIndex = 0
  private var fns: [Int: [() -> Void]] = [:]

  typealias FenceID = ObjectIdentifier
  private var fenceBoundTasks: [FenceID: (Fence, [() -> Void])] = [:]

  var cycleSize = 3

  func flushWithFences(_ context: DeviceContext) {
    let values = Array(fenceBoundTasks.values)
    for (fence, tasks) in values {
      do {
        try context.device.waitForFences(fences: [fence], waitAll: true, timeout: 0)

        // to shut up the validation layer 
        try context.device.waitForFences(fences: [fence], waitAll: true, timeout: UInt64.max)
        fenceBoundTasks[ObjectIdentifier(fence)] = nil
        for t in tasks { t() }
      } catch {
        // not yet signaled
      }
    }

    flush()
  }

  func flush() {
    currentIndex += 1

    if let toRun = fns[currentIndex] {
      for fn in toRun {
        fn()
      }
    }
    fns[currentIndex] = nil
  }

  func scheduleNextCycle(_ block: @escaping () -> Void) {
    schedule(in: cycleSize + 1, block)
  }

  func schedule(in loopCount: Int = 1, _ block: @escaping () -> Void) {
    if fns.keys.contains(currentIndex + loopCount) {
      fns[currentIndex + loopCount]!.append(block)
    } else {
      fns[currentIndex + loopCount] = [block]
    }
  }

  func schedule(after fence: Fence, withFrame: Bool = true, _ block: @escaping () -> Void) {
    if !withFrame {
      fatalError("use thread pool to wait for fence is not yet implemented")
    }

    // fenceBoundTasks[fence, default: [() -> Void]]
    var tasks = fenceBoundTasks[ObjectIdentifier(fence)]
    if tasks == nil {
      tasks = (fence, [])
    }

    tasks!.1.append(block)
    fenceBoundTasks[ObjectIdentifier(fence)] = tasks
  }

}
