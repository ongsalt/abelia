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
    // vmaUnmapMemory(allocator, allocation)
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


class VmaImage {
    let image: Image
    let view: ImageView
    private let allocation: VmaAllocation
    private let allocator: VmaAllocator
    let size: SIMD2<UInt32>

    init(
        _ image: Image, _ view: ImageView,
        _ allocation: VmaAllocation,
        _ allocator: VmaAllocator,
        size: SIMD2<UInt32>
    ) {
        self.image = image
        self.view = view
        self.allocation = allocation
        self.allocator = allocator
        self.size = size
    }

    init(
        size: SIMD2<UInt32>,
        format: Format,
        usages: ImageUsageFlags = [.sampled, .colorAttachment],
        context: borrowing DeviceContext
    ) throws(Vulkan.Result) {
        let device = context.device
        var vkImage: VkImage?
        var vmaAlloc: VmaAllocation?
        var vmaCi = VmaAllocationCreateInfo()
        vmaCi.usage = VMA_MEMORY_USAGE_AUTO
        let extent = Extent3D(width: size.x, height: size.y, depth: 1)
        try checkResult(
            ImageCreateInfo(
                imageType: .type2d,
                format: format,
                extent: extent,
                mipLevels: 1,
                arrayLayers: 1,
                samples: .type1,
                tiling: .optimal,
                usage: usages,
                sharingMode: .exclusive,
                initialLayout: .undefined
            ).withCStruct {
                vmaCreateImage(context.allocator, $0, &vmaCi, &vkImage, &vmaAlloc, nil)
            }
        )

        self.image = Image(handle: vkImage!, device: device)
        self.view = try device.createImageView(
            .init(
                image: image,
                viewType: .type2d,
                format: format,
                components: .init(r: .r, g: .g, b: .b, a: .a),
                subresourceRange: .init(
                    aspectMask: .color, baseMipLevel: 0, levelCount: 1,
                    baseArrayLayer: 0, layerCount: 1)
            )
        )

        self.allocation = vmaAlloc!
        self.size = size
        self.allocator = context.allocator
    }

    func destroy() {
        view.destroy()
        vmaDestroyImage(allocator, image.handle, allocation)
    }
}
