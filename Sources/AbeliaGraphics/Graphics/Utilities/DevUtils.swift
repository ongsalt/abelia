import Foundation

extension DeviceContext {
  public func loadImageFr(url: URL) throws {
    let (image, _) = try self.loadImage(filename: url.absoluteString)
    // image
  }
}
