@preconcurrency import CVulkan
import Pointer

public class GraphicsDevice {
  private let physicalDevice: VkPhysicalDevice
  let handle: VkDevice
  private let vma: VmaAllocator
  let selectedQueueIndexes: SelectedQueues

  let capabilities: VkSurfaceCapabilitiesKHR

  let presentQueue: VkQueue
  let graphicsQueue: VkQueue
  let transferQueue: VkQueue

  private let cleanupQueue = CleanUpQueue()

  init(instance: VkInstance, compatibleWith surface: Surface) {
    let selected = selectPhysicalDevice(instance: instance, compatibleWith: surface)
    self.selectedQueueIndexes = selected.1
    self.physicalDevice = selected.0
    self.capabilities = selected.2
    self.handle = createDevice(physicalDevice: selected.0, queues: selected.1)

    var presentQueue: VkQueue?
    vkGetDeviceQueue(self.handle, UInt32(selectedQueueIndexes.present), 0, &presentQueue)
    self.presentQueue = presentQueue!

    var graphicsQueue: VkQueue?
    vkGetDeviceQueue(self.handle, UInt32(selectedQueueIndexes.graphics), 0, &graphicsQueue)
    self.graphicsQueue = graphicsQueue!

    var transferQueue: VkQueue?
    vkGetDeviceQueue(self.handle, UInt32(selectedQueueIndexes.transfer), 0, &transferQueue)
    self.transferQueue = transferQueue!

    self.vma = createVMA(instance: instance, physicalDevice: physicalDevice, logicalDevice: handle)
  }

  public func createSwapchain(for surface: Surface) -> Swapchain {
    Swapchain(for: surface, on: self, size: capabilities.currentExtent.asSimd)
  }

  public func createCompositionPipeline(compatibleWith swapchain: borrowing Swapchain)
    -> CompositionPipeline
  {
    CompositionPipeline(device: self, swapchain: swapchain)
  }

  deinit {
  }
}

private let deviceExtensions = CStringArray {
  "VK_KHR_swapchain"
  "VK_KHR_external_fence"
  #if os(Linux)
    "VK_KHR_external_fence_fd"
  #endif
  #if os(Windows)
    "VK_KHR_external_memory"
    "VK_KHR_external_memory_win32"
  #endif
}

private func createDevice(physicalDevice: VkPhysicalDevice, queues: SelectedQueues) -> VkDevice {
  let uniqueIndexes = queues.uniques
  let property: Box<Float> = Box(1.0)
  let queueCi = CArray(
    uniqueIndexes.map { index in
      return VkDeviceQueueCreateInfo(
        sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        pNext: nil,
        flags: 0,
        queueFamilyIndex: UInt32(index),
        queueCount: 1,
        pQueuePriorities: property.ptr
      )
    }
  )

  let features = Box(VkPhysicalDeviceFeatures()) {
    // TODO: why do i even need this
    $0.samplerAnisotropy = true
  }

  let enabledVk11Features = Box(VkPhysicalDeviceVulkan11Features()) {
    $0.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES
    $0.shaderDrawParameters = true

  }

  let enabledVk12Features = Box(VkPhysicalDeviceVulkan12Features()) {
    $0.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES
    $0.pNext = enabledVk11Features.rawMut
    $0.descriptorIndexing = true
    $0.descriptorBindingVariableDescriptorCount = true
    $0.descriptorBindingSampledImageUpdateAfterBind = true
    // $0.descriptorBindingPartiallyBound = true
    $0.runtimeDescriptorArray = true
    $0.bufferDeviceAddress = true

    $0.shaderSampledImageArrayNonUniformIndexing = true
  }

  let enabledVk13Features = Box(VkPhysicalDeviceVulkan13Features()) {
    $0.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES
    $0.pNext = enabledVk12Features.rawMut
    $0.synchronization2 = true
    $0.dynamicRendering = true
  }

  var ci = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    pNext: enabledVk13Features.ptr,
    flags: 0,
    queueCreateInfoCount: queueCi.count,
    pQueueCreateInfos: queueCi.ptr,
    // device layer is deprecated
    enabledLayerCount: 0,
    ppEnabledLayerNames: nil,
    enabledExtensionCount: deviceExtensions.count,
    ppEnabledExtensionNames: deviceExtensions.ptr,
    pEnabledFeatures: features.ptr
  )
  var device: VkDevice?
  vkCreateDevice(physicalDevice, &ci, nil, &device).expect("Cannot create device")

  volkLoadDevice(device)

  return device!
}

private func selectPhysicalDevice(instance: VkInstance, compatibleWith surface: Surface) -> (
  VkPhysicalDevice, SelectedQueues, VkSurfaceCapabilitiesKHR
) {
  let devices = Vulkan.enumerate { count, arr in
    vkEnumeratePhysicalDevices(instance, count, arr)
  }

  if devices.count == 0 {
    fatalError("No vulkan device")
  }

  var suitableDevices: [(VkPhysicalDevice, SelectedQueues, VkSurfaceCapabilitiesKHR)] = []
  for device in devices {
    if let queues = getQueues(device: device!, surface: surface) {
      var capabilities = VkSurfaceCapabilitiesKHR()
      vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface.handle, &capabilities)
        .unwrap()
      suitableDevices.append((device!, queues, capabilities))
    }
  }

  return suitableDevices[0]
}

struct SelectedQueues {
  var graphics: Int
  var present: Int
  // var compute: Int
  var transfer: Int

  var isCompleted: Bool {
    graphics != -1 && present != -1 && transfer != -1
  }

  var uniques: Set<Int> {
    Set([graphics, present, transfer])
  }
}

private func getQueues(device: VkPhysicalDevice, surface: Surface) -> SelectedQueues? {
  var p: VkPhysicalDeviceProperties2 = VkPhysicalDeviceProperties2()
  p.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2

  vkGetPhysicalDeviceProperties2(device, &p)

  let name = String(cStringPointer: &p.properties.deviceName)
  print("- \(name)")

  // TODO: actually picking the device
  //  - prioritize need DGPU
  //  - deprioritize llvmpipe
  //  - we can ignore swapchain support if we are dealing with DirectComposition

  var tf = VkQueueFamilyProperties2()
  tf.sType = VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2
  let supportedQueues: [VkQueueFamilyProperties2] = Vulkan.enumerate(defaultValue: tf) {
    count, arr in
    vkGetPhysicalDeviceQueueFamilyProperties2(device, count, arr)
  }

  var selectedQueues = SelectedQueues(
    graphics: -1,
    present: -1,
    transfer: -1
  )
  for (index, queue) in supportedQueues.enumerated() {
    if queue.queueFamilyProperties.queueFlags & VK_QUEUE_GRAPHICS_BIT.u32 != 0
      && selectedQueues.graphics == -1
    {
      selectedQueues.graphics = index
    }

    if queue.queueFamilyProperties.queueFlags & VK_QUEUE_TRANSFER_BIT.u32 != 0
      && selectedQueues.transfer == -1
    {
      selectedQueues.transfer = index
    }

    var presentSupported: VkBool32 = false
    vkGetPhysicalDeviceSurfaceSupportKHR(device, UInt32(index), surface.handle, &presentSupported)
      .unwrap()
    if presentSupported.isTrue() && selectedQueues.present == -1 {
      selectedQueues.present = index
    }
  }

  return if selectedQueues.isCompleted {
    selectedQueues
  } else {
    nil
  }
}

func createVMA(
  instance: VkInstance,
  physicalDevice: VkPhysicalDevice,
  logicalDevice: VkDevice,
) -> VmaAllocator {
  var vmaCi = Box(Mem.zeroed(of: VmaAllocatorCreateInfo.self)) {
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
  vmaImportVulkanFunctionsFromVolk(vmaCi.ptr, vulkanFunctions.mut).expect(
    "Cannot import vulkan fns from volk")
  vmaCi.value.pVulkanFunctions = vulkanFunctions.ptr

  var allocator: VmaAllocator?
  vmaCreateAllocator(vmaCi.ptr, &allocator).expect("Cannot create vma")

  return allocator!
}
