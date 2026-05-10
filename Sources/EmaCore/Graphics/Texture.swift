struct TextureUsages: OptionSet {
  let rawValue: Int

  static let colorAttachment = TextureUsages(rawValue: 1 << 0)
  static let sampled = TextureUsages(rawValue: 2 << 0)
  static let transferDestination = TextureUsages(rawValue: 3 << 0)

  // static let raster = colorAttachment | sampled
}


class Texture {
  let cleanUpQueue: CleanUpQueue
  var size: Size<UInt32> = .zero 
  // var size: Size<UInt32> = .zero 

  init(cleanUpQueue: CleanUpQueue) {
    self.cleanUpQueue = cleanUpQueue
  }

  deinit {
    cleanUpQueue.schedule {

    }
  }
}
