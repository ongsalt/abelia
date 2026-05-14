@preconcurrency import CVulkan
import Pointer

struct BufferUsages: OptionSet {
  let rawValue: Int

  // for layer storage
  static let storage = BufferUsages(rawValue: 1 << 0)
  static let vertex = BufferUsages(rawValue: 2 << 0)
  // static let index = BufferUsages(rawValue: 3 << 0)
  static let staging = BufferUsages(rawValue: 4 << 0)
  static let uniform = BufferUsages(rawValue: 5 << 0)
}

// staging buffer is not representable by this class

class GPUBuffer {
  let buffer: UnsafeMutableRawBufferPointer
  let usages: BufferUsages
  let device: GraphicsDevice
  let handle: VkBuffer
  let allocation: VmaAllocation

  init(device: GraphicsDevice, size: UInt64, usages: BufferUsages) {
    self.usages = usages
    self.device = device

    (self.handle, self.allocation) = createBuffer(device: device, size: size, usages: usages)

    var ptr: UnsafeMutableRawPointer?
    vmaMapMemory(device.vma, self.allocation, &ptr)
    // print("vmaMapMemory's ptr = \(ptr!)")
    self.buffer = UnsafeMutableRawBufferPointer(start: ptr, count: Int(size))
  }
}

// https://gpuopen-librariesandsdks.github.io/VulkanMemoryAllocator/html/usage_patterns.html
func createBuffer(device: GraphicsDevice, size: UInt64, usages: BufferUsages)
  -> (VkBuffer, VmaAllocation)
{
  var ci = with(VkBufferCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
    $0.size = size
    $0.sharingMode = VK_SHARING_MODE_EXCLUSIVE

    // we dont really need index buffer
    // if usages.contains(.index) {
    //   $0.usage |= VK_BUFFER_USAGE_INDEX_BUFFER_BIT.u32
    // }
    if usages.contains(.vertex) {
      $0.usage |= VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.u32
    }

    if usages.contains(.uniform) {
      $0.usage |= VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT.u32
    }

    if usages.contains(.staging) {
      $0.usage |= VK_BUFFER_USAGE_TRANSFER_SRC_BIT.u32
    }

    if usages.contains(.storage) {
      $0.usage |= VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.u32
    }
  }

  var allocationCi = with(VmaAllocationCreateInfo()) {
    $0.flags =
      VMA_ALLOCATION_CREATE_MAPPED_BIT.u32
      | VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT.u32

    $0.usage = VMA_MEMORY_USAGE_CPU_TO_GPU
    // $0.requiredFlags =  VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.
  }

  var buffer: VkBuffer?
  var allocation: VmaAllocation?
  vmaCreateBuffer(device.vma, &ci, &allocationCi, &buffer, &allocation, nil).unwrap()

  return (buffer!, allocation!)
}
