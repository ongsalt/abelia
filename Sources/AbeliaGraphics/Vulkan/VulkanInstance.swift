@preconcurrency import CVulkan

// we should actually let the user pass this in
public final class VulkanInstance {
    let instance: VkInstance

    public init() throws(VulkanError) {
        try volkInitialize().expect("volkInitialize")
        let supportedVersion = volkGetInstanceVersion()
        guard supportedVersion >= vulkanAPIVersion else {
            throw .unsupportedAPIVersion(supported: supportedVersion)
        }

        var allocator = BumpAllocator()
        instance = try createInstance(allocator: allocator.createFrame())
        volkLoadInstance(instance)
    }

    deinit {
        vkDestroyInstance(instance, nil)
    }

    #if os(Linux)
        /// The returned object owns its native surface and retains this instance.
        /// Keep the Wayland display and surface alive while the Vulkan surface is in use.
        public func createSurface(display: OpaquePointer, surface: OpaquePointer)
            throws(VulkanError) -> Surface
        {
            var info = VkWaylandSurfaceCreateInfoKHR()
            info.sType = VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR
            info.display = display
            info.surface = surface

            var result: VkSurfaceKHR?
            try vkCreateWaylandSurfaceKHR(instance, &info, nil, &result)
                .expect("vkCreateWaylandSurfaceKHR")
            return Surface(result!)
        }
    #endif
}

let vulkanAPIVersion: UInt32 = (1 << 22) | (3 << 12)  // Vulkan 1.3

private var instanceExtensions: [String] {
    #if os(Linux)
        ["VK_KHR_surface", "VK_KHR_wayland_surface"]
    #elseif os(Windows)
        [
            "VK_KHR_surface",
            "VK_KHR_win32_surface",
            "VK_KHR_external_memory",
            "VK_KHR_external_memory_win32",
            "VK_KHR_external_semaphore_win32",
        ]
    #else
        []
    #endif
}

private func createInstance(allocator: consuming FrameAllocator)
    throws(VulkanError) -> VkInstance
{
    var applicationInfo = VkApplicationInfo()
    applicationInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    applicationInfo.pApplicationName = allocator.string("Abelia")
    applicationInfo.pEngineName = allocator.string("Abelia")
    applicationInfo.apiVersion = vulkanAPIVersion

    var instanceInfo = VkInstanceCreateInfo()
    instanceInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    instanceInfo.pApplicationInfo = UnsafePointer(allocator.write(applicationInfo))
    instanceInfo.enabledExtensionCount = UInt32(instanceExtensions.count)
    instanceInfo.ppEnabledExtensionNames = allocator.stringArray(instanceExtensions)

    var instance: VkInstance?
    try vkCreateInstance(&instanceInfo, nil, &instance).expect("vkCreateInstance")
    return instance!
}
