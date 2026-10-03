@preconcurrency import CVulkan

class VulkanDevice {
    let instance: VulkanInstance
    let physicalDevice: VkPhysicalDevice
    let device: VkDevice
    let functions: VolkDeviceTable
    let graphicsQueue: VkQueue
    let graphicsQueueFamilyIndex: UInt32
    let allocator: VmaAllocator

    init(
        instance: VulkanInstance,
        physicalDevice: VkPhysicalDevice,
        device: VkDevice,
        graphicsQueueFamilyIndex: UInt32,
        allocator: VmaAllocator
    ) {
        self.instance = instance
        self.physicalDevice = physicalDevice
        self.device = device
        var functions = VolkDeviceTable()
        volkLoadDeviceTable(&functions, device)
        self.functions = functions
        var graphicsQueue: VkQueue?
        functions.vkGetDeviceQueue(device, graphicsQueueFamilyIndex, 0, &graphicsQueue)
        self.graphicsQueue = graphicsQueue!
        self.graphicsQueueFamilyIndex = graphicsQueueFamilyIndex
        self.allocator = allocator
    }

    deinit {
        functions.vkDestroyDevice(device, nil)
    }
}
