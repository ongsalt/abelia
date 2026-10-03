@preconcurrency import CVulkan

extension VulkanInstance {
    /// Requests a device with a graphics queue that can present to this instance's surface.
    func requestDevice(compatibleWith surface: Surface? = nil) throws(VulkanError) -> VulkanDevice {
        let nativeSurface: VkSurfaceKHR? = surface?.vkSurface
        var allocator = BumpAllocator()
        let selection = try selectGraphicsDevice(
            instance: instance,
            surface: nativeSurface,
            allocator: allocator.createFrame()
        )

        let device = try createDevice(
            physicalDevice: selection.physicalDevice,
            graphicsQueueFamilyIndex: selection.queueFamilyIndex,
            allocator: allocator.createFrame()
        )

        let vma = createVMA(self, device: device, physicalDevice: selection.physicalDevice)

        return VulkanDevice(
            instance: self,
            physicalDevice: selection.physicalDevice,
            device: device,
            graphicsQueueFamilyIndex: selection.queueFamilyIndex,
            allocator: vma
        )
    }
}

private let deviceExtensions = ["VK_KHR_swapchain"]

private nonisolated(unsafe) let requiredVulkan12Features:
    [WritableKeyPath<VkPhysicalDeviceVulkan12Features, VkBool32>] = [
        \.bufferDeviceAddress,
        \.timelineSemaphore,
        \.descriptorIndexing,
        \.runtimeDescriptorArray,
        \.descriptorBindingPartiallyBound,
        \.descriptorBindingUpdateUnusedWhilePending,
        \.descriptorBindingSampledImageUpdateAfterBind,
        \.descriptorBindingStorageImageUpdateAfterBind,
        \.shaderSampledImageArrayNonUniformIndexing,
        \.shaderStorageImageArrayNonUniformIndexing,
    ]

private nonisolated(unsafe) let requiredVulkan13Features:
    [WritableKeyPath<VkPhysicalDeviceVulkan13Features, VkBool32>] = [
        \.synchronization2,
        \.dynamicRendering,
    ]

private func selectGraphicsDevice(
    instance: VkInstance,
    surface: VkSurfaceKHR?,
    allocator: consuming FrameAllocator
) throws(VulkanError) -> (physicalDevice: VkPhysicalDevice, queueFamilyIndex: UInt32) {
    while true {
        // Query again if the device list grows between enumeration calls.
        var frame = allocator.createFrame()
        var deviceCount: UInt32 = 0
        try vkEnumeratePhysicalDevices(instance, &deviceCount, nil)
            .expect("vkEnumeratePhysicalDevices")
        guard deviceCount > 0 else { throw .noGraphicsDevice }

        let devices = frame.allocate(VkPhysicalDevice?.self, count: Int(deviceCount))
        let result = try vkEnumeratePhysicalDevices(instance, &deviceCount, devices)
            .expectNonNegative("vkEnumeratePhysicalDevices")
        if result == VK_INCOMPLETE { continue }

        for index in 0..<Int(deviceCount) {
            guard let physicalDevice = devices[index] else { continue }
            var properties = VkPhysicalDeviceProperties()
            vkGetPhysicalDeviceProperties(physicalDevice, &properties)
            
            guard properties.apiVersion >= vulkanAPIVersion else { continue }

            guard
                try supportsDeviceExtensions(
                    physicalDevice: physicalDevice, allocator: frame.createFrame()
                )
            else { continue }
            guard
                supportsRequiredFeatures(
                    physicalDevice: physicalDevice, allocator: frame.createFrame()
                )
            else { continue }

            if let queueFamilyIndex = try graphicsQueueFamily(
                physicalDevice: physicalDevice, surface: surface, allocator: frame.createFrame()
            ) {
                return (physicalDevice, queueFamilyIndex)
            }
        }
        throw .noGraphicsDevice
    }
}

private func supportsDeviceExtensions(
    physicalDevice: VkPhysicalDevice,
    allocator: consuming FrameAllocator
) throws(VulkanError) -> Bool {
    while true {
        var frame = allocator.createFrame()
        var count: UInt32 = 0
        try vkEnumerateDeviceExtensionProperties(physicalDevice, nil, &count, nil)
            .expect("vkEnumerateDeviceExtensionProperties")
        guard count > 0 else { return false }
        let extensions = frame.allocate(VkExtensionProperties.self, count: Int(count))
        let result = try vkEnumerateDeviceExtensionProperties(
            physicalDevice, nil, &count, extensions
        )
        .expectNonNegative("vkEnumerateDeviceExtensionProperties")
        if result == VK_INCOMPLETE { continue }

        var names = Set<String>()
        for index in 0..<Int(count) {
            let name = withUnsafePointer(to: &extensions[index].extensionName) {
                $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
            }
            names.insert(name)
        }
        return deviceExtensions.allSatisfy { names.contains($0) }
    }
}

private func supportsRequiredFeatures(
    physicalDevice: VkPhysicalDevice,
    allocator: consuming FrameAllocator
) -> Bool {
    let chain = featureChain(allocator: &allocator, enableRequired: false)
    var features = VkPhysicalDeviceFeatures2()
    features.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2
    features.pNext = UnsafeMutableRawPointer(chain.localRead)
    vkGetPhysicalDeviceFeatures2(physicalDevice, &features)

    return requiredVulkan12Features.allSatisfy { chain.vulkan12.pointee[keyPath: $0] != 0 }
        && requiredVulkan13Features.allSatisfy { chain.vulkan13.pointee[keyPath: $0] != 0 }
        && chain.localRead.pointee.dynamicRenderingLocalRead != 0
}

private func featureChain(
    allocator: inout FrameAllocator,
    enableRequired: Bool
) -> (
    vulkan12: UnsafeMutablePointer<VkPhysicalDeviceVulkan12Features>,
    vulkan13: UnsafeMutablePointer<VkPhysicalDeviceVulkan13Features>,
    localRead: UnsafeMutablePointer<VkPhysicalDeviceDynamicRenderingLocalReadFeatures>
) {
    let vulkan13 = allocator.write(VkPhysicalDeviceVulkan13Features())
    vulkan13.pointee.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES
    let vulkan12 = allocator.write(VkPhysicalDeviceVulkan12Features())
    vulkan12.pointee.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES
    vulkan12.pointee.pNext = UnsafeMutableRawPointer(vulkan13)
    let localRead = allocator.write(VkPhysicalDeviceDynamicRenderingLocalReadFeatures())
    localRead.pointee.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_LOCAL_READ_FEATURES
    localRead.pointee.pNext = UnsafeMutableRawPointer(vulkan12)

    if enableRequired {
        localRead.pointee.dynamicRenderingLocalRead = true.vk
        for feature in requiredVulkan12Features { vulkan12.pointee[keyPath: feature] = 1 }
        for feature in requiredVulkan13Features { vulkan13.pointee[keyPath: feature] = 1 }
    }
    return (vulkan12, vulkan13, localRead)
}

private func graphicsQueueFamily(
    physicalDevice: VkPhysicalDevice,
    surface: VkSurfaceKHR?,
    allocator: consuming FrameAllocator
) throws(VulkanError) -> UInt32? {
    var familyCount: UInt32 = 0
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &familyCount, nil)
    guard familyCount > 0 else { return nil }

    let families = allocator.allocate(VkQueueFamilyProperties.self, count: Int(familyCount))
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &familyCount, families)

    for index in 0..<Int(familyCount) {
        let family = families[index]
        let supportsGraphics = family.queueFlags & VK_QUEUE_GRAPHICS_BIT.rawValue != 0
        guard family.queueCount > 0 && supportsGraphics else { continue }

        if let surface {
            var supportsPresentation: VkBool32 = 0
            try vkGetPhysicalDeviceSurfaceSupportKHR(
                physicalDevice, UInt32(index), surface, &supportsPresentation
            ).expect("vkGetPhysicalDeviceSurfaceSupportKHR")
            if supportsPresentation != 0 { return UInt32(index) }
        } else {
            return UInt32(index)
        }
    }
    return nil
}

private func createDevice(
    physicalDevice: VkPhysicalDevice,
    graphicsQueueFamilyIndex: UInt32,
    allocator: consuming FrameAllocator
) throws(VulkanError) -> VkDevice {
    var queueInfo = VkDeviceQueueCreateInfo()
    queueInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    queueInfo.queueFamilyIndex = graphicsQueueFamilyIndex
    queueInfo.queueCount = 1
    queueInfo.pQueuePriorities = UnsafePointer(allocator.write(Float(1)))

    let features = featureChain(allocator: &allocator, enableRequired: true)
    var deviceInfo = VkDeviceCreateInfo()
    deviceInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    deviceInfo.pNext = UnsafeRawPointer(features.localRead)
    deviceInfo.enabledExtensionCount = UInt32(deviceExtensions.count)
    deviceInfo.ppEnabledExtensionNames = allocator.stringArray(deviceExtensions)
    deviceInfo.queueCreateInfoCount = 1
    deviceInfo.pQueueCreateInfos = UnsafePointer(allocator.write(queueInfo))

    var device: VkDevice?
    try vkCreateDevice(physicalDevice, &deviceInfo, nil, &device).expect("vkCreateDevice")
    return device!
}

private func createVMA(
    _ vulkanInstance: VulkanInstance, device: VkDevice, physicalDevice: VkPhysicalDevice
) -> VmaAllocator {
    var allocator: VmaAllocator?
    var vkFunctions = VmaVulkanFunctions()
    vkFunctions.vkGetDeviceProcAddr = vkGetDeviceProcAddr
    vkFunctions.vkGetInstanceProcAddr = vkGetInstanceProcAddr
    withUnsafePointer(to: vkFunctions) { vkFunctions in
        var vmaCi = VmaAllocatorCreateInfo(
            flags: UInt32(VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT.rawValue)
                | UInt32(VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT.rawValue)
                | UInt32(VMA_ALLOCATOR_CREATE_EXT_MEMORY_PRIORITY_BIT.rawValue),
            physicalDevice: physicalDevice,
            device: device,
            preferredLargeHeapBlockSize: 0,
            pAllocationCallbacks: nil,
            pDeviceMemoryCallbacks: nil,
            pHeapSizeLimit: nil,
            pVulkanFunctions: vkFunctions,
            instance: vulkanInstance.instance,
            vulkanApiVersion: vulkanAPIVersion,
            pTypeExternalMemoryHandleTypes: nil
        )
        #if os(Windows)
            vmaCi.flags |= UInt32(VMA_ALLOCATOR_CREATE_KHR_EXTERNAL_MEMORY_WIN32_BIT.rawValue)
        #endif
        vmaCreateAllocator(&vmaCi, &allocator)
    }

    return allocator!
}
