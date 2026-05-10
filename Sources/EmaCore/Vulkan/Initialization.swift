@preconcurrency import CVulkan
import Pointer

#if os(Windows)
  import WinSDK
#endif

private let instanceLayers = CStringArray {
  #if DEBUG
    "VK_LAYER_KHRONOS_validation"
  #endif
}
private let instanceExtensions = CStringArray {
  "VK_KHR_get_physical_device_properties2"
  "VK_KHR_surface"
  "VK_KHR_external_fence_capabilities"
  #if os(Windows)
    "VK_KHR_win32_surface"
  #endif
  #if os(Linux)
    "VK_KHR_wayland_surface"
  #endif
}

func createVulkanInstance(appName: String, engineName: String = "Ema") -> VkInstance {
  volkInitialize()
  var instance: VkInstance?

  let appName = CString(appName)
  let engineName = CString(engineName)
  let appInfo = Box(
    VkApplicationInfo(
      sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
      pNext: nil,
      pApplicationName: appName.ptr,
      applicationVersion: Vulkan.makeVersion(major: 1, minor: 0, patch: 0),
      pEngineName: engineName.ptr,
      engineVersion: Vulkan.makeVersion(major: 1, minor: 0, patch: 0),
      apiVersion: Vulkan.apiVersion
    )
  )

  var instanceCi = VkInstanceCreateInfo(
    sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    pNext: nil,
    flags: VkInstanceCreateFlags(),
    pApplicationInfo: appInfo.ptr,
    enabledLayerCount: instanceLayers.count,
    ppEnabledLayerNames: instanceLayers.ptr,
    enabledExtensionCount: instanceExtensions.count,
    ppEnabledExtensionNames: instanceExtensions.ptr
  )

  vkCreateInstance(&instanceCi, nil, &instance).expect("Cannot create vulkan device")
  volkLoadInstance(instance)
  return instance!
}

