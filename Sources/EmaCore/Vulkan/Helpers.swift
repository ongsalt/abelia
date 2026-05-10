import CVulkan

extension RawRepresentable where RawValue: BinaryInteger {
  // enum is i32 on windows for some reason
  // this is a shitty fix
  var u32: UInt32 {
    unsafeBitCast(self.rawValue, to: UInt32.self)
  }
}

extension VkBool32: @retroactive ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self =
      if value {
        VK_TRUE
      } else {
        VK_FALSE
      }
  }

  public typealias BooleanLiteralType = Bool
}
extension VkBool32 {
  func isTrue() -> Bool {
    self == 1
  }
}
extension VkResult {
  func isOk() -> Bool {
    self == VK_SUCCESS
  }

  func expect(_ message: String, line: Int = #line, file: String = #file) {
    if self.rawValue < 0 {
      let m = "\(message), code: \(self.rawValue) at \(file):\(line)"
      // Log.error(.vulkan, "error code: \(self.rawValue)")
      fatalError(m)
    }
    if self != VK_SUCCESS {
      // Log.warn(.vulkan, "Not VK_SUCCESS: \(self.rawValue)")
    }
  }

  func unwrap(line: Int = #line, file: String = #file) {
    expect("unwrap failed", line: line, file: file)
  }

  func unwrapOrElse<E>(line: Int = #line, file: String = #file, _ block: () throws(E) -> Void)
    throws(E)
  {
    if self.rawValue < 0 {
      try block()
    }
    if self != VK_SUCCESS {
      // Log.warn(.vulkan, "Not VK_SUCCESS: \(self.rawValue)")
    }
  }

  func throwing() throws(VulkanError) {
    if self.rawValue < 0 {
      throw VulkanError(code: self)
    }
  }

  struct VulkanError: Error {
    let code: VkResult
  }
}

enum Vulkan {}
extension Vulkan {
  static func makeVersion(major: UInt32, minor: UInt32, patch: UInt32) -> UInt32 {
    return (major << 22) | (minor << 12) | patch
  }

  static func makeApiVersion(variant: UInt32, major: UInt32, minor: UInt32, patch: UInt32)
    -> UInt32
  {
    return (variant << 29) | (major << 22) | (minor << 12) | patch
  }

  static let apiVersion1_0 = makeApiVersion(variant: 0, major: 1, minor: 0, patch: 0)
  static let apiVersion1_3 = makeApiVersion(variant: 0, major: 1, minor: 3, patch: 0)
  static let apiVersion = apiVersion1_3

  static func enumerate<T>(
    defaultValue: T = uninitializedMemory(of: T.self),
    line: Int = #line,
    file: String = #file,
    _ fn: (UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<T>?) -> VkResult
  ) -> [T] {
    var count: UInt32 = 0
    var array: [T] = []
    fn(&count, nil).expect("get array failed", line: line, file: file)

    array = Array(repeating: defaultValue, count: Int(count))
    fn(&count, &array).expect("get array failed", line: line, file: file)

    return array
  }

  static func enumerate<T>(
    defaultValue: T = uninitializedMemory(of: T.self),
    _ fn: (UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<T>?) -> Void
  ) -> [T] {
    enumerate(defaultValue: defaultValue) { count, arr in
      fn(count, arr)
      return VkResult(0)
    }
  }

}

func uninitializedMemory<T>(of type: T.Type) -> T {
  withUnsafeTemporaryAllocation(of: type, capacity: 1) { buffer in
    buffer[0]
  }
}
