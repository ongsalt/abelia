import CShim
import Vulkan

public class GraphicsContext: @unchecked Sendable {
    let vulkanEntry: Entry
    public let vulkanInstance: Instance
    public private(set) var surfaceContexts: [SurfaceContext] = []

    public init(applicationName: String? = nil, version: UInt32 = 1) throws {
        self.vulkanEntry = try Entry()
        self.vulkanInstance = try self.vulkanEntry.createInstance(
            .init(
                applicationInfo: .init(
                    applicationName: applicationName,
                    applicationVersion: version,
                    engineVersion: 1,
                    apiVersion: .init(major: 1, minor: 3, patch: 0)
                ),
                enabledLayerNames: {
                    var layers: [String] = []
                    #if DEBUG
                        layers.append("VK_LAYER_KHRONOS_validation")
                    #endif
                    return layers
                }(),
                enabledExtensionNames: {
                    var extensions = [
                        "VK_KHR_surface"
                        // "VK_KHR_external_fence_capabilities",
                    ]
                    #if os(Windows)
                        extensions.append("VK_KHR_win32_surface")
                    #endif
                    #if os(Linux)
                        extensions.append("VK_KHR_wayland_surface")
                    #endif  // os(Linux)

                    return extensions
                }()
            )
        )
    }

    public func createWaylandSurface(display: OpaquePointer, surface: OpaquePointer) throws(Vulkan
        .Result)
        -> SurfaceKHR
    {
        try vulkanInstance.createWaylandSurfaceKHR(.init(display: display, surface: surface))
    }

    // func createWin32Surface(display: OpaquePointer, surface: OpaquePointer) throws(Vulkan.Result)
    //     -> SurfaceKHR
    // {
    //     try vulkanInstance.createWin32Surface(.init(display: display, surface: surface))
    // }

    public func initDevice(compatibleWith surface: SurfaceKHR)
        throws(DeviceInitializationError)
    {
        self.surfaceContexts.append(try SurfaceContext(compatibleWith: surface, context: self))
    }

}

public enum DeviceInitializationError: Error {
    case noUsableDevice
}

public class SurfaceContext: @unchecked Sendable {
    let surface: SurfaceKHR
    let physicalDevice: PhysicalDevice
    let graphicsFamilyIndex: UInt32
    let presentationFamilyIndex: UInt32
    let graphicsQueue: Queue
    let presentationQueue: Queue
    let device: Device
    let allocator: VmaAllocator

    public init(compatibleWith surface: SurfaceKHR, context: borrowing GraphicsContext)
        throws(DeviceInitializationError)
    {
        guard
            let (graphicsFamilyIndex, presentationFamilyIndex, physicalDevice) =
                try? Self.selectPhysicalDevice(context.vulkanInstance, compatibleWith: surface),
            let device = try? physicalDevice.createDevice(
                DeviceCreateInfo(
                    queueCreateInfos: Set([graphicsFamilyIndex, presentationFamilyIndex])
                        .map { .init(queueFamilyIndex: $0, queuePriorities: [1.0]) },
                    enabledExtensionNames: [
                        "VK_KHR_swapchain"
                    ],
                )
                .push(PhysicalDeviceBufferDeviceAddressFeatures(bufferDeviceAddress: true))
                .push(
                    PhysicalDeviceVulkan13Features(
                        synchronization2: true,
                        dynamicRendering: true,
                    )
                )
                .push(PhysicalDeviceVulkan11Features(shaderDrawParameters: true))
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
                flags: VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT.rawValue
                    | VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT.rawValue
                    | VMA_ALLOCATOR_CREATE_EXT_MEMORY_PRIORITY_BIT.rawValue,
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
                vmaCi.flags |= VMA_ALLOCATOR_CREATE_KHR_EXTERNAL_MEMORY_WIN32_BIT.u32
            #endif
            vmaCreateAllocator(&vmaCi, &allocator)
        }

        self.surface = surface
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

    static func selectPhysicalDevice(_ instance: Instance, compatibleWith surface: SurfaceKHR)
        throws(Vulkan.Result) -> (
            graphicsFamilyIndex: UInt32, presentationFamilyIndex: UInt32,
            physicalDevice: PhysicalDevice
        )?
    {
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
            let surfaceFormats = try physicalDevice.getSurfaceFormatsKHR(surface: surface)
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
                            queueFamilyIndex: $0, surface: surface)
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
