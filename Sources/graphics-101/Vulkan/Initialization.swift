@preconcurrency import CVMA
import Glibc
import Wayland

private let instanceLayers = CStringArray {
    #if DEBUG
        "VK_LAYER_KHRONOS_validation"
    #endif
}
private let instanceExtensions: CStringArray = [
    "VK_KHR_get_physical_device_properties2",
    "VK_KHR_external_fence_capabilities",
    "VK_KHR_surface",
    "VK_KHR_wayland_surface",
]

private let deviceLayers: CStringArray = []
private let deviceExtensions: CStringArray = [
    "VK_KHR_swapchain",
    "VK_KHR_external_fence",
    "VK_KHR_external_fence_fd",
]

private func createInstance() -> VkInstance {
    volkInitialize()
    var instance: VkInstance! = VkInstance(bitPattern: 0)

    // how long should this be alive tho
    let appName = CString("yomum")
    let engineName = CString("yomum engine")
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

    // TODO: check for availability
    // print(instanceLayers.ptr)
    // print(instanceExtensions.ptr)
    var createInfo = VkInstanceCreateInfo(
        sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pNext: nil,
        flags: VkInstanceCreateFlags(),
        pApplicationInfo: appInfo.readonly,

        enabledLayerCount: instanceLayers.count,
        ppEnabledLayerNames: instanceLayers.ptr,

        // FIXME: add more extension when it complain
        enabledExtensionCount: instanceExtensions.count,
        ppEnabledExtensionNames: instanceExtensions.ptr
    )

    // var allocationCallback = VkAllocationCallbacks(
    //     pUserData: UnsafeMutableRawPointer!,
    //     pfnAllocation: (UnsafeMutableRawPointer?, Int, Int, VkSystemAllocationScope) -> UnsafeMutableRawPointer?, pfnReallocation: (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int, Int, VkSystemAllocationScope) -> UnsafeMutableRawPointer?, pfnFree: (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void, pfnInternalAllocation: (UnsafeMutableRawPointer?, Int, VkInternalAllocationType, VkSystemAllocationScope) -> Void, pfnInternalFree: (UnsafeMutableRawPointer?, Int, VkInternalAllocationType, VkSystemAllocationScope) -> Void
    // )

    let result = vkCreateInstance(&createInfo, nil, &instance)
    guard result.rawValue == 0 else {
        fatalError(
            "Cannot create vulkan instance [code: \(result)] pls see https://docs.vulkan.org/refpages/latest/refpages/source/VkResult.html"
        )
    }

    volkLoadInstance(instance)

    // print("result \(result), instance: \(instance)")

    return instance
}

private func createWaylandSurface(
    instance: VkInstance, waylandDisplay: OpaquePointer, waylandSurface: OpaquePointer
) -> VkSurfaceKHR {
    var createInfo = VkWaylandSurfaceCreateInfoKHR(
        sType: VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
        pNext: nil,
        flags: VkWaylandSurfaceCreateFlagsKHR(),
        display: waylandDisplay,
        surface: waylandSurface
    )

    var surface: VkSurfaceKHR? = nil

    vkCreateWaylandSurfaceKHR(
        instance,
        &createInfo,
        nil,
        &surface
    ).expect("Cannot create wayland surface")

    return surface!
}

// TODO: device picking logic: checkDeviceExtensionSupport
private func pickPhysicalDevice(instance: VkInstance) -> VkPhysicalDevice {
    var count: UInt32 = 0
    vkEnumeratePhysicalDevices(instance, &count, nil)

    var devices: [VkPhysicalDevice?] = Array(
        repeating: nil, count: Int(count))
    vkEnumeratePhysicalDevices(instance, &count, &devices)

    for device in devices {
        var properties = VkPhysicalDeviceProperties()
        vkGetPhysicalDeviceProperties(device, &properties)

        var deviceFeatures = VkPhysicalDeviceFeatures()

        vkGetPhysicalDeviceFeatures(device, &deviceFeatures)

        // let name = String(cStringPointer: &properties.deviceName)
        // print(name)
        // print(deviceFeatures)
    }

    return devices[0]!

}

struct SelectedQueuesIndices {
    let graphicsFamily: Int?
    let presentFamily: Int?

    var uniqueCount: Int {
        let s: Set<Int?> = [graphicsFamily, presentFamily]
        return s.count
    }
}

private func findQueueFamilies(device: VkPhysicalDevice, surface: VkSurfaceKHR)
    -> SelectedQueuesIndices
{
    var count: UInt32 = 0
    vkGetPhysicalDeviceQueueFamilyProperties(device, &count, nil)

    var queues = Array(
        repeating: VkQueueFamilyProperties(), count: Int(count))
    vkGetPhysicalDeviceQueueFamilyProperties(device, &count, &queues)

    let graphicsFamily = queues.firstIndex {
        $0.queueFlags & VK_QUEUE_GRAPHICS_BIT.rawValue != 0
    }!

    var presentFamily: Int? = nil
    var supportPresentation: VkBool32 = false
    vkGetPhysicalDeviceSurfaceSupportKHR(
        device, UInt32(graphicsFamily), surface, &supportPresentation)
    if supportPresentation.isTrue() {
        presentFamily = graphicsFamily
    }

    return SelectedQueuesIndices(
        graphicsFamily: graphicsFamily,
        presentFamily: presentFamily
    )
}

private func createLogicalDevice(families: SelectedQueuesIndices, physicalDevice: VkPhysicalDevice)
    -> (device: VkDevice, graphicsQueue: VkQueue, presentQueue: VkQueue)
{

    let priority = Box(Float(1.0))

    let queueCreateInfos = Array(
        repeating: VkDeviceQueueCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            pNext: nil,
            flags: VkDeviceQueueCreateFlags(),
            queueFamilyIndex: UInt32(families.graphicsFamily!),
            queueCount: 1,
            pQueuePriorities: priority.ptr
        ),
        count: families.uniqueCount
    )

    let deviceFeatures = Box(VkPhysicalDeviceFeatures())
    deviceFeatures[].samplerAnisotropy = true

    let device = queueCreateInfos.withUnsafeBufferPointer { queueCreateInfos in
        let enabledVk12Features = Box(VkPhysicalDeviceVulkan12Features())
        enabledVk12Features[].sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES
        enabledVk12Features[].descriptorIndexing = true
        enabledVk12Features[].descriptorBindingVariableDescriptorCount = true
        enabledVk12Features[].runtimeDescriptorArray = true
        enabledVk12Features[].bufferDeviceAddress = true

        let enabledVk13Features = Box(VkPhysicalDeviceVulkan13Features())
        enabledVk13Features[].sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES
        enabledVk13Features[].pNext = UnsafeMutableRawPointer(enabledVk12Features.opaque)
        enabledVk13Features[].synchronization2 = true
        enabledVk13Features[].dynamicRendering = true

        var deviceCreateInfo = VkDeviceCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            pNext: enabledVk13Features.ptr,
            flags: VkDeviceCreateFlags(),
            queueCreateInfoCount: 1,
            pQueueCreateInfos: queueCreateInfos.baseAddress,
            enabledLayerCount: deviceLayers.count,
            ppEnabledLayerNames: deviceLayers.ptr,
            enabledExtensionCount: deviceExtensions.count,
            ppEnabledExtensionNames: deviceExtensions.ptr,
            pEnabledFeatures: deviceFeatures.ptr
        )

        var device: VkDevice? = nil
        let result = vkCreateDevice(physicalDevice, &deviceCreateInfo, nil, &device)
        guard result.rawValue == 0 else {
            fatalError(
                "Can't create vulkan device [code: \(result)] pls see https://docs.vulkan.org/refpages/latest/refpages/source/VkResult.html"
            )
        }

        return device!

    }

    var graphicsQueue: VkQueue? = nil
    var presentQueue: VkQueue? = nil
    vkGetDeviceQueue(device, UInt32(families.graphicsFamily!), 0, &graphicsQueue)
    vkGetDeviceQueue(device, UInt32(families.presentFamily!), 0, &presentQueue)

    return (
        device: device,
        graphicsQueue: graphicsQueue!,
        presentQueue: presentQueue!
    )
}

private func createVMA(
    instance: VkInstance,
    physicalDevice: VkPhysicalDevice,
    logicalDevice: VkDevice,
) -> VmaAllocator {
    let allocatorCreateInfo = Box(createZeroedStruct(of: VmaAllocatorCreateInfo.self))
    allocatorCreateInfo[].physicalDevice = physicalDevice
    allocatorCreateInfo[].device = logicalDevice
    allocatorCreateInfo[].instance = instance
    allocatorCreateInfo[].vulkanApiVersion = Vulkan.apiVersion
    allocatorCreateInfo[].flags =
        VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT.rawValue
        | VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT.rawValue
        | VMA_ALLOCATOR_CREATE_EXT_MEMORY_PRIORITY_BIT.rawValue
    #if os(Windows)
        allocatorCreateInfo[].flags |= VMA_ALLOCATOR_CREATE_KHR_EXTERNAL_MEMORY_WIN32_BIT.rawValue
    #endif

    let vulkanFunctions = Box(VmaVulkanFunctions())
    vmaImportVulkanFunctionsFromVolk(allocatorCreateInfo.ptr, vulkanFunctions.ptr)

    allocatorCreateInfo[].pVulkanFunctions = vulkanFunctions.readonly

    var allocator: VmaAllocator? = VmaAllocator(bitPattern: 0)
    let res = vmaCreateAllocator(allocatorCreateInfo.ptr, &allocator)
    guard res.rawValue == 0 else {
        fatalError("createVMA failed with result: \(res)")
    }

    return allocator!
}

class VulkanState: @unchecked Sendable {
    let instance: VkInstance
    let surface: VkSurfaceKHR
    let physicalDevice: VkPhysicalDevice
    let device: VkDevice

    let families: SelectedQueuesIndices
    let graphicsQueue: VkQueue
    let presentQueue: VkQueue
    // let pipeline: VkPipeline
    let commandPool: VkCommandPool
    let commandBuffers: [VkCommandBuffer]
    let maxFramesInFlight: UInt32 = 1

    let swapChain: SwapChain

    let allocator: VmaAllocator

    init(waylandDisplay: OpaquePointer, waylandSurface: OpaquePointer) {
        instance = createInstance()

        surface = createWaylandSurface(
            instance: instance, waylandDisplay: waylandDisplay, waylandSurface: waylandSurface)

        physicalDevice = pickPhysicalDevice(instance: instance)

        // no VK_EXT_blend_operation_advanced
        // Vulkan.printAvailableDeviceExtension(physicalDevice: physicalDevice)

        families = findQueueFamilies(device: physicalDevice, surface: surface)
        let c = createLogicalDevice(families: families, physicalDevice: physicalDevice)
        self.graphicsQueue = c.graphicsQueue
        self.presentQueue = c.presentQueue
        self.device = c.device

        let graphicsFamilyIndex = UInt32(families.graphicsFamily!)

        allocator = createVMA(
            instance: instance, physicalDevice: physicalDevice, logicalDevice: device)

        self.swapChain = SwapChain(
            surface: surface,
            physicalDevice: physicalDevice,
            logicalDevice: device,
            families: families
        )

        let (pool, cmdBuffer) = VulkanState.createCommandPool(
            device: device, queueFamilyIndex: graphicsFamilyIndex, swapChain: swapChain)
        self.commandPool = pool
        self.commandBuffers = cmdBuffer
    }

    consuming func destroy() {
        commandBuffers.withUnsafeBufferPointer {
            vkFreeCommandBuffers(
                device, commandPool, UInt32($0.count),
                UnsafeMutablePointer(OpaquePointer($0.baseAddress)))
        }
        vkDestroyCommandPool(device, commandPool, nil)
        swapChain.destroy()
        vkDestroySurfaceKHR(instance, surface, nil)
        vkDestroyDevice(device, nil)
        vkDestroyInstance(instance, nil)
    }

    private static func createCommandPool(
        device: VkDevice, queueFamilyIndex: UInt32, swapChain: SwapChain
    )
        -> (VkCommandPool, [VkCommandBuffer])
    {
        let commandPoolCI = Box(VkCommandPoolCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
            $0.flags = VkCommandPoolCreateFlags(
                VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT.rawValue
            )
            $0.queueFamilyIndex = queueFamilyIndex
        }

        let commandPool = with(VkCommandPool(bitPattern: 0)) {
            vkCreateCommandPool(device, commandPoolCI.ptr, nil, &$0).unwrap()
        }!

        var commandBuffers = Array(
            repeating: VkCommandBuffer(bitPattern: 0), count: Int(swapChain.framesInFlightCount))

        let cbAllocCI = Box(VkCommandBufferAllocateInfo()) { [commandPool, swapChain] in
            $0.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
            $0.commandPool = commandPool
            $0.commandBufferCount = UInt32(swapChain.framesInFlightCount)
        }

        vkAllocateCommandBuffers(device, cbAllocCI.ptr, &commandBuffers).unwrap()

        return (commandPool, commandBuffers.unwrapPointer())
    }

    deinit {
        // TODO: wait for idle
        destroy()
    }
}
