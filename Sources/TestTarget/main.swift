import CShim
import Vulkan

func makeApiVersion(variant: UInt32, major: UInt32, minor: UInt32, patch: UInt32)
    -> UInt32
{
    return (variant << 29) | (major << 22) | (minor << 12) | patch
}

let entry = try Entry()
let instance = try entry.createInstance(
    .init(
        applicationInfo: .init(
            applicationVersion: 12,
            engineVersion: 100,
            apiVersion: .init(major: 1, minor: 3, patch: 0)
        ),
        enabledLayerNames: ["VK_LAYER_KHRONOS_validation"]
    )
)
let physicalDevices = try instance.getPhysicalDevices()

var ci = DeviceCreateInfo()
    // .push(PhysicalDeviceBufferDeviceAddressFeatures(bufferDeviceAddress: true))
    // .push(
    //     PhysicalDeviceVulkan13Features(
    //         synchronization2: true,
    //         dynamicRendering: true,
    //     )
    // )
let device = try physicalDevices[0].createDevice(ci)

var allocator: VmaAllocator?

var vkFunctions = VmaVulkanFunctions()
vkFunctions.vkGetDeviceProcAddr = instance.dispatchTable.vkGetDeviceProcAddr
vkFunctions.vkGetInstanceProcAddr = entry.loader.vkGetInstanceProcAddr

withUnsafePointer(to: vkFunctions) { vkFunctions in
    var vmaCi = VmaAllocatorCreateInfo(
        flags: VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT.rawValue
            | VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT.rawValue
            | VMA_ALLOCATOR_CREATE_EXT_MEMORY_PRIORITY_BIT.rawValue,
        physicalDevice: physicalDevices[0].handle!,
        device: device.handle!,
        preferredLargeHeapBlockSize: 0,
        pAllocationCallbacks: nil,
        pDeviceMemoryCallbacks: nil,
        pHeapSizeLimit: nil,
        pVulkanFunctions: vkFunctions,
        instance: instance.handle!,
        vulkanApiVersion: makeApiVersion(variant: 0, major: 1, minor: 3, patch: 0),
        pTypeExternalMemoryHandleTypes: nil
    )
    #if os(Windows)
        vmaCi.flags |= VMA_ALLOCATOR_CREATE_KHR_EXTERNAL_MEMORY_WIN32_BIT.u32
    #endif

    vmaCreateAllocator(&vmaCi, &allocator)
}

print(allocator!)
