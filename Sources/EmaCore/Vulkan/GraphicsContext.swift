@preconcurrency import CVulkan

public struct GraphicsContext {
  let instance: VkInstance
  // we need a surface before picking device 
  private(set) public var device: GraphicsDevice?
}

extension GraphicsContext {
  public init(appName: String) {
    let instance = createVulkanInstance(appName: appName)
    // TODO: might setup vulkan debugger
    self.init(
      instance: instance,
      device: nil
    )
  }

  @discardableResult
  public mutating func initDevice(compatibleWith surface: Surface) -> GraphicsDevice {
    self.device = GraphicsDevice(instance: instance, compatibleWith: surface)
    return self.device!
  }
}
