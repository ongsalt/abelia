import CShim
import Vulkan

#if os(Windows)
    import WinSDK
#endif

public class GraphicsContext: @unchecked Sendable {
    let vulkanEntry: Entry
    public let vulkanInstance: Instance

    #if DEBUG
        var debugMessenger: DebugUtilsMessengerEXT
    #endif  // DEBUG

    public init(applicationName: String? = nil, version: UInt32 = 1) throws {
        self.vulkanEntry = try Entry()

        var layers: [String] = []
        var extensions: [String] = [
            "VK_KHR_surface"
        ]

        #if DEBUG
            layers.append("VK_LAYER_KHRONOS_validation")
            extensions.append("VK_EXT_debug_utils")
        #endif

        #if os(Windows)
            extensions.append("VK_KHR_win32_surface")
        #elseif os(Linux)
            extensions.append("VK_KHR_wayland_surface")
        #endif

        self.vulkanInstance = try self.vulkanEntry.createInstance(
            .init(
                applicationInfo: .init(
                    applicationName: applicationName,
                    applicationVersion: version,
                    engineVersion: 1,
                    apiVersion: .init(major: 1, minor: 3, patch: 0)
                ),
                enabledLayerNames: layers,
                enabledExtensionNames: extensions
            )
        )

        #if DEBUG
            debugMessenger = try vulkanInstance.createDebugUtilsMessengerEXT(
                .init(
                    flags: [],
                    messageSeverity: [.warning, .error],
                    messageType: [.general, .performance, .validation],
                    pfnUserCallback: { severity, type, callbackData, userData in
                        print("[vulkan] \(String(cString: callbackData!.pointee.pMessage))")
                        print()
                        return 0
                    },
                    userData: nil
                )
            )
        #endif

    }

    #if os(Linux)
        public func createWaylandSurface(display: OpaquePointer, surface: OpaquePointer)
            throws(Vulkan.Result) -> Surface
        {
            Surface(
                try vulkanInstance.createWaylandSurfaceKHR(
                    .init(display: display, surface: surface)))
        }
    #endif

    #if os(Windows)
        public func createWin32Surface(hinstance: HINSTANCE, hwnd: HWND)
            throws(Vulkan.Result) -> Surface
        {
            Surface(
                try vulkanInstance.createWin32SurfaceKHR(.init(hinstance: hinstance, hwnd: hwnd)))
        }
    #endif

    public func createDevice(compatibleWith surface: Surface)
        throws(DeviceInitializationError) -> DeviceContext
    {
        return try DeviceContext(compatibleWith: surface, context: self)
    }

    // temporary api
    public func createRenderer(for surface: any SurfaceProtocol, device: DeviceContext) throws
        -> Renderer
    {
        try Renderer(context: device, maxFrameInFlightCount: 2)
    }

}
public enum DeviceInitializationError: Error {
    case noUsableDevice
}
public class DeviceContext: @unchecked Sendable {
    let physicalDevice: PhysicalDevice
    let graphicsFamilyIndex: UInt32
    let presentationFamilyIndex: UInt32
    let graphicsQueue: Queue
    let presentationQueue: Queue
    let device: Device
    let allocator: VmaAllocator

    init(compatibleWith surface: any SurfaceProtocol, context: borrowing GraphicsContext)
        throws(DeviceInitializationError)
    {
        guard
            let (graphicsFamilyIndex, presentationFamilyIndex, physicalDevice) =
                try? Self.selectPhysicalDevice(context.vulkanInstance, compatibleWith: surface),
            let device = try? physicalDevice.createDevice(
                DeviceCreateInfo(
                    queueCreateInfos: Set([graphicsFamilyIndex, presentationFamilyIndex])
                        .map { .init(queueFamilyIndex: $0, queuePriorities: [1.0]) },
                    enabledExtensionNames: {
                        var names = ["VK_KHR_swapchain"]

                        #if os(Windows)
                            names += [
                                "VK_KHR_external_memory",
                                "VK_KHR_external_memory_win32",
                            ]
                        #endif

                        return names
                    }(),
                )
                .push(PhysicalDeviceVulkan12Features(
                    shaderSampledImageArrayNonUniformIndexing: true,
                    // shaderStorageBufferArrayNonUniformIndexing: true,
                    descriptorBindingSampledImageUpdateAfterBind: true,
                    descriptorBindingPartiallyBound: true,
                    descriptorBindingVariableDescriptorCount: true,
                    runtimeDescriptorArray: true,
                    bufferDeviceAddress: true,
                ))
                .push(PhysicalDeviceVulkan11Features(shaderDrawParameters: true))
                .push(
                    PhysicalDeviceVulkan13Features(
                        synchronization2: true,
                        dynamicRendering: true,
                    )
                )
            )
        else {
            throw .noUsableDevice
        }

        var allocator: VmaAllocator?
        var vkFunctions = VmaVulkanFunctions()
        vkFunctions.vkGetDeviceProcAddr = context.vulkanInstance.dispatchTable.vkGetDeviceProcAddr
        vkFunctions.vkGetInstanceProcAddr = context.vulkanEntry.loader.vkGetInstanceProcAddr
        withUnsafePointer(to: vkFunctions) { vkFunctions in
            var vmaCi = VmaAllocatorCreateInfo(
                flags: UInt32(VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT.rawValue)
                    | UInt32(VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT.rawValue)
                    | UInt32(VMA_ALLOCATOR_CREATE_EXT_MEMORY_PRIORITY_BIT.rawValue),
                physicalDevice: physicalDevice.handle!,
                device: device.handle!,
                preferredLargeHeapBlockSize: 0,
                pAllocationCallbacks: nil,
                pDeviceMemoryCallbacks: nil,
                pHeapSizeLimit: nil,
                pVulkanFunctions: vkFunctions,
                instance: context.vulkanInstance.handle!,
                vulkanApiVersion: Version(major: 1, minor: 3, patch: 0).rawValue,
                pTypeExternalMemoryHandleTypes: nil
            )
            #if os(Windows)
                vmaCi.flags |= UInt32(VMA_ALLOCATOR_CREATE_KHR_EXTERNAL_MEMORY_WIN32_BIT.rawValue)
            #endif
            vmaCreateAllocator(&vmaCi, &allocator)
        }

        self.physicalDevice = physicalDevice
        self.graphicsFamilyIndex = graphicsFamilyIndex
        self.presentationFamilyIndex = presentationFamilyIndex
        self.graphicsQueue = device.getQueue2(
            .init(queueFamilyIndex: graphicsFamilyIndex, queueIndex: 0))
        self.presentationQueue = device.getQueue2(
            .init(queueFamilyIndex: presentationFamilyIndex, queueIndex: 0))
        self.device = device
        self.allocator = allocator!
    }

    static func selectPhysicalDevice(
        _ instance: Instance, compatibleWith surface: any SurfaceProtocol
    )
        throws(Vulkan.Result) -> (
            graphicsFamilyIndex: UInt32, presentationFamilyIndex: UInt32,
            physicalDevice: PhysicalDevice
        )?
    {
        guard let surface = surface as? Surface else {
            fatalError("Unimplemented")
        }
        let physicalDevices = try instance.getPhysicalDevices()

        for physicalDevice in physicalDevices {

            // Device must support the VK_KHR_swapchain extension
            let extensions = try physicalDevice.getDeviceExtensionProperties(layerName: nil)
            guard
                extensions.contains(where: {
                    $0.extensionName == VK_KHR_SWAPCHAIN_EXTENSION_NAME
                })
            else {
                continue
            }

            // Device must support the b8g8r8a8Srgb / srgbNonLinear surface format.
            let surfaceFormats = try physicalDevice.getSurfaceFormatsKHR(surface: surface.handle)
            guard
                surfaceFormats.contains(where: {
                    $0.format == .b8g8r8a8Srgb && $0.colorSpace == .srgbNonlinear
                })
            else {
                continue
            }

            // Device must have a graphics queue family.
            let queueFamilies = physicalDevice.getQueueFamilyProperties()
            guard
                let graphicsFamilyIndex = queueFamilies.firstIndex(where: {
                    $0.queueFlags.contains(.graphics)
                })
            else {
                continue
            }

            // Device must have a presentation queue family that is compatible with the surface.
            let queueFamilyIndices = 0..<UInt32(queueFamilies.count)
            do {
                guard
                    let presentationFamilyIndex = try queueFamilyIndices.first(where: {
                        try physicalDevice.getSurfaceSupportKHR(
                            queueFamilyIndex: $0, surface: surface.handle)
                    })
                else {
                    continue
                }

                return (UInt32(graphicsFamilyIndex), presentationFamilyIndex, physicalDevice)
            } catch {
                throw error as! Vulkan.Result
            }
        }

        return nil
    }
}
