@preconcurrency import CVulkan

#if os(Windows)
  import WinSDK
#endif

public class Surface {
  let surface: VkSurfaceKHR

  #if os(linux)
    // init() {}
  #endif
  #if os(Windows)
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

      var surface: VkSurfaceKHR? = nil

      vkCreateWin32SurfaceKHR(
        context.instance,
        &ci,
        nil,
        &surface
      ).expect("Cannot create win32 surface")

      self.surface = surface!
    }
  #endif

}

class Swapchain {

}

class SwapchainImage {

}
