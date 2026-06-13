import CShim
import Vulkan

class VmaBuffer {
  let buffer: Buffer
  let allocation: VmaAllocation
  let allocator: VmaAllocator
  let bufferPointer: UnsafeMutableRawBufferPointer?

  init(
    _ buffer: Buffer, _ allocation: VmaAllocation, _ allocator: VmaAllocator,
    bufferPointer: UnsafeMutableRawBufferPointer? = nil
  ) {
    self.buffer = buffer
    self.allocation = allocation
    self.allocator = allocator
    self.bufferPointer = bufferPointer
  }

  func destroy() {
    vmaDestroyBuffer(allocator, buffer.handle, allocation)
  }
}

extension DeviceContext {
  func createVmaBuffer(
    size: UInt64,
    usages: BufferUsageFlags = .storageBuffer,
    mapped: Bool = true
  )
    throws(Vulkan.Result) -> VmaBuffer
  {
    try self.createVmaBuffer(
      .init(
        size: size,
        usage: usages,
        sharingMode: .exclusive
      ),
      mapped: mapped
    )
  }

  func createVmaBuffer(
    _ createInfo: BufferCreateInfo,
    mapped: Bool = true
  )
    throws(Vulkan.Result) -> VmaBuffer
  {
    var vmaCi: VmaAllocationCreateInfo = VmaAllocationCreateInfo()
    if mapped {
      vmaCi.flags =
        UInt32(VMA_ALLOCATION_CREATE_MAPPED_BIT.rawValue)
        | UInt32(VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT.rawValue)

      vmaCi.usage = VMA_MEMORY_USAGE_AUTO
    }

    var buffer: VkBuffer!
    var allocation: VmaAllocation!

    let result = createInfo.withCStruct { ci in
      // TODO: export checkResult
      vmaCreateBuffer(allocator, ci, &vmaCi, &buffer, &allocation, nil)
    }

    try checkResult(result)

    var bufferPointer: UnsafeMutableRawBufferPointer?
    if mapped {
      var ptr: UnsafeMutableRawPointer?
      vmaMapMemory(allocator, allocation, &ptr)
      bufferPointer = UnsafeMutableRawBufferPointer(start: ptr, count: Int(createInfo.size))
    }

    return VmaBuffer(
      Buffer(handle: buffer, device: device), allocation, allocator, bufferPointer: bufferPointer)
  }
}
