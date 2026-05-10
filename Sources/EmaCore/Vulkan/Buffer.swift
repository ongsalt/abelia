struct BufferUsages: OptionSet {
  let rawValue: Int

  static let ssbo = BufferUsages(rawValue: 1 << 0)
  static let vertex = BufferUsages(rawValue: 2 << 0)
  static let index = BufferUsages(rawValue: 3 << 0)
  static let transferSource = BufferUsages(rawValue: 4 << 0)
}

class Buffer {
  let cleanUpQueue: CleanUpQueue
  init(cleanUpQueue: CleanUpQueue) {
    self.cleanUpQueue = cleanUpQueue
  }

  deinit {
    cleanUpQueue.schedule {

    }
  }
}
