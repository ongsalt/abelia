class CleanUpQueue {
  private var queue: [() -> Void] = []

  func schedule(_ block: @escaping () -> Void) {
    queue.append(block)
  }

  func flush() {
    let q = queue
    queue = []
    for fn in q {
      fn()
    }
  }
}


