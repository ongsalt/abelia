@preconcurrency import CVulkan

#if os(Windows)
  import WinSDK
#endif

struct ConfiguredSurfaceInfo {
  let device: GraphicsDevice
  let swapchain: any SwapchainProtocol
  var capabilities: VkSurfaceCapabilitiesKHR
}

public class Surface: @unchecked Sendable {
  let handle: VkSurfaceKHR
  var configuredInfo: ConfiguredSurfaceInfo?

  #if os(linux)
    // init() {}
  #endif
  #if os(Windows)
    let hwnd: WinSDK.HWND
    public init(
      _ context: GraphicsContext,
      hinstance: WinSDK.HINSTANCE,
      hwnd: WinSDK.HWND,
    ) {
      var ci = VkWin32SurfaceCreateInfoKHR(
        sType: VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        pNext: nil,
        flags: VkWin32SurfaceCreateFlagsKHR(),
        hinstance: hinstance,
        hwnd: hwnd
      )

      self.hwnd = hwnd
      var surface: VkSurfaceKHR? = nil

      vkCreateWin32SurfaceKHR(
        context.instance,
        &ci,
        nil,
        &surface
      ).expect("Cannot create win32 surface")

      self.handle = surface!
    }
  #endif

  public func configure(associateWith device: GraphicsDevice, config: Void = ()) {
    var capabilities = VkSurfaceCapabilitiesKHR()
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.physicalDevice, self.handle, &capabilities)
      .unwrap()

    // #if os(Windows)
    // let swapchain = DXGISwapchain(
    //   hwnd: self.hwnd, on: device, initialSize: capabilities.currentExtent.asSimd)
    // #else
    let swapchain = Swapchain(
      for: self, on: device, initialSize: capabilities.currentExtent.asSimd,
      surfaceCapabilities: capabilities)
    // #endif
    self.configuredInfo = ConfiguredSurfaceInfo(
      device: device,
      swapchain: swapchain,
      capabilities: capabilities
    )
  }

  func reconfigure() {
    guard let configuredInfo else {
      fatalError("Not yet configured")
    }

    var caps = configuredInfo.capabilities
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
      configuredInfo.device.physicalDevice, self.handle, &caps
    )
    .unwrap()
    self.configuredInfo!.capabilities = caps
  }
}
