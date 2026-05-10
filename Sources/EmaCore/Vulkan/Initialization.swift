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


func createVMA(
  instance: VkInstance,
  physicalDevice: VkPhysicalDevice,
  logicalDevice: VkDevice,
) -> VmaAllocator {
  var vmaCi = Box(uninitializedMemory(of: VmaAllocatorCreateInfo.self)) {
    $0.physicalDevice = physicalDevice
    $0.device = logicalDevice
    $0.instance = instance
    $0.vulkanApiVersion = Vulkan.apiVersion
    $0.flags =
      VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT.u32
      | VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT.u32
      | VMA_ALLOCATOR_CREATE_EXT_MEMORY_PRIORITY_BIT.u32
    #if os(Windows)
      $0.flags |= VMA_ALLOCATOR_CREATE_KHR_EXTERNAL_MEMORY_WIN32_BIT.u32
    #endif
  }

  let vulkanFunctions = Box(VmaVulkanFunctions())
  vmaImportVulkanFunctionsFromVolk(vmaCi.ptr, vulkanFunctions.mut)
  vmaCi.value.pVulkanFunctions = vulkanFunctions.ptr

  var allocator: VmaAllocator?
  vmaCreateAllocator(vmaCi.ptr, &allocator).expect("Cannot create vma")

  return allocator!
}

