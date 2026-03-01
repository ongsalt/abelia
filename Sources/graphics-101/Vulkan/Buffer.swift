@preconcurrency import CVMA
import Foundation
import Wayland

class GPUBuffer<BufferData> {
    let mapped: UnsafeMutableBufferPointer<BufferData>
    let deviceAddress: VkDeviceAddress
    private let vmaAllocator: VmaAllocator
    private let vmaAllocation: VmaAllocation
    // this is to please the ffi
    var buffer: VkBuffer?

    var capacity: Int {
        mapped.count
    }

    convenience init(
        indexBuffer data: [UInt32], allocator: VmaAllocator, device: VkDevice, count: Int? = nil
    ) where BufferData == UInt32 {
        self.init(
            data: data, allocator: allocator, device: device, count: count ?? 1024 * 16,
            usages: VK_BUFFER_USAGE_INDEX_BUFFER_BIT)
    }

    convenience init(
        vertexBuffer data: [BufferData], allocator: VmaAllocator, device: VkDevice,
        count: Int? = nil
    ) {
        self.init(
            data: data, allocator: allocator, device: device, count: count,
            usages: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT)
    }

    // we should pass usages too
    convenience init(
        data: [BufferData], allocator: VmaAllocator, device: VkDevice, count: Int? = nil,
        usages: VkBufferUsageFlagBits? = nil
    ) {
        self.init(
            of: BufferData.self, allocator: allocator, device: device, count: count,
            usages: usages)

        self.mapped.initialize(from: data)
    }

    // Create this per frame in flight
    init(
        of: BufferData.Type,
        allocator: VmaAllocator,
        device: VkDevice,
        count: Int? = nil,
        usages: VkBufferUsageFlagBits? = nil
    ) {
        // well, its ~11 f32 -> ~ 64 byte each * 1000 vertex = 64Kb
        // fuck, just do 1mb ->
        // we have 16 bind point max, each is 16 byte
        let count = count ?? ((1024 * 1024) / MemoryLayout<BufferData>.size)
        let size = count * MemoryLayout<BufferData>.size

        var bufferCI = VkBufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            size: UInt64(size),
            usage: (usages?.rawValue ?? 0) | (VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT).rawValue,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil
        )

        var bufferAllocCI = VmaAllocationCreateInfo(
            flags: VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT.rawValue
                | VMA_ALLOCATION_CREATE_HOST_ACCESS_ALLOW_TRANSFER_INSTEAD_BIT.rawValue
                | VMA_ALLOCATION_CREATE_MAPPED_BIT.rawValue,
            usage: VMA_MEMORY_USAGE_AUTO,
            requiredFlags: 0,
            preferredFlags: 0,
            memoryTypeBits: 0,
            pool: nil,
            pUserData: nil,
            priority: 0
        )

        var buffer: VkBuffer?
        var mapped: UnsafeMutableRawPointer?
        var allocation: VmaAllocation?

        vmaCreateBuffer(allocator, &bufferCI, &bufferAllocCI, &buffer, &allocation, nil).expect(
            "failed to create vertex buffer")
        vmaMapMemory(allocator, allocation!, &mapped).expect("Failed to map memory")

        // now we can write to
        let swiftBuffer = UnsafeMutableBufferPointer(
            start: mapped!.assumingMemoryBound(to: BufferData.self), count: count)

        var uBufferBdaInfo = with(VkBufferDeviceAddressInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO
            $0.buffer = buffer
        }

        self.deviceAddress = vkGetBufferDeviceAddress(device, &uBufferBdaInfo)
        self.mapped = swiftBuffer
        self.buffer = buffer!
        self.vmaAllocation = allocation!
        self.vmaAllocator = allocator
    }

    func set(_ data: [BufferData]) {
        mapped.initialize(from: data)
    }

    deinit {
        vmaUnmapMemory(vmaAllocator, vmaAllocation)
        vmaDestroyBuffer(vmaAllocator, buffer, vmaAllocation)
    }

}


// TODO: gpu local buffer
class RawGPUBuffer {
    let mapped: UnsafeMutableRawPointer
    let deviceAddress: VkDeviceAddress
    private let vmaAllocator: VmaAllocator
    private let vmaAllocation: VmaAllocation
    // this is to please ffi
    var buffer: VkBuffer?
    let capacity: Int

    init(
        allocator: VmaAllocator,
        device: VkDevice,
        size: Int = 1024 * 1024,
        usages: VkBufferUsageFlagBits? = VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
    ) {
        capacity = size

        var bufferCI = VkBufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            size: UInt64(size),
            usage: (usages?.rawValue ?? 0)
                | VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT.rawValue,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil
        )

        var bufferAllocCI = VmaAllocationCreateInfo(
            flags: VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT.rawValue
                | VMA_ALLOCATION_CREATE_HOST_ACCESS_ALLOW_TRANSFER_INSTEAD_BIT.rawValue
                | VMA_ALLOCATION_CREATE_MAPPED_BIT.rawValue,
            usage: VMA_MEMORY_USAGE_AUTO,
            requiredFlags: 0,
            preferredFlags: 0,
            memoryTypeBits: 0,
            pool: nil,
            pUserData: nil,
            priority: 0
        )

        var buffer: VkBuffer?
        var mapped: UnsafeMutableRawPointer?
        var allocation: VmaAllocation?

        vmaCreateBuffer(allocator, &bufferCI, &bufferAllocCI, &buffer, &allocation, nil).expect(
            "failed to create vertex buffer")
        vmaMapMemory(allocator, allocation!, &mapped).expect("Failed to map memory")

        // now we can write to

        var uBufferBdaInfo = with(VkBufferDeviceAddressInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO
            $0.buffer = buffer
        }

        self.deviceAddress = vkGetBufferDeviceAddress(device, &uBufferBdaInfo)
        self.mapped = mapped!
        self.buffer = buffer!
        self.vmaAllocation = allocation!
        self.vmaAllocator = allocator
    }

    func write<BufferData>(_ data: [BufferData], offset: Int = 0) -> Int {
        if offset + data.count * MemoryLayout<BufferData>.size > capacity {
            fatalError("data is larger than allocated buffer")
        }

        (mapped + offset).initializeMemory(as: BufferData.self, from: data, count: data.count)

        return data.count * MemoryLayout<BufferData>.size
    }

    deinit {
        vmaUnmapMemory(vmaAllocator, vmaAllocation)
        vmaDestroyBuffer(vmaAllocator, buffer, vmaAllocation)
    }
}
