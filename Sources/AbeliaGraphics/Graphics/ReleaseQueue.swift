class ReleaseQueue {
  private var currentIndex = 0
  private var fns: [Int: [() -> Void]] = [:]

  var cycleSize = 3

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
}
