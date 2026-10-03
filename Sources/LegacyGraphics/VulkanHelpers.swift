import Foundation
import Vulkan

extension Vulkan.Extent2D: @unchecked @retroactive Sendable {}
extension Vulkan.Extent2D {
  static let zero = Self(width: 0, height: 0)

  func clamped(from lowerBound: Self, to upperBound: Self) -> Self {
    Self(
      width: width.clamped(from: lowerBound.width, to: upperBound.width),
      height: height.clamped(from: lowerBound.height, to: upperBound.height)
    )
  }
}
extension Vulkan.Offset2D: @unchecked @retroactive Sendable {}
extension Vulkan.Offset2D {
  static let zero = Self(x: 0, y: 0)
}

extension Vulkan.Offset3D: @unchecked @retroactive Sendable {}
extension Vulkan.Offset3D {
  static let zero = Self(x: 0, y: 0, z: 0)
}

extension Vulkan.Device {
  func createShaderModule(filename: String) -> ShaderModule? {
    let url = Bundle.module.url(forResource: "Resources/\(filename)", withExtension: "spv")!

    guard let shaderData = try? Data(contentsOf: url) else {
      return nil
    }

    return try? shaderData.withUnsafeBytes { bytes in
      try self.createShaderModule(
        .init(
          codeSize: bytes.count,
          code: bytes.baseAddress!.assumingMemoryBound(to: UInt32.self)
        )
      )
    }
  }
}
extension Vulkan.Rect2D: @unchecked @retroactive Sendable {}
extension Vulkan.Rect2D {
  static let zero = Rect2D(offset: .zero, extent: .zero)
}

extension Vulkan.VkOffset3D {
  static let zero = VkOffset3D(x: 0, y: 0, z: 0)
}
