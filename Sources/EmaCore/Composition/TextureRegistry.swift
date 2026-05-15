@preconcurrency import CVulkan
import Pointer

class TextureRegistry {
  private let device: GraphicsDevice

  let imagesDescriptorPool: VkDescriptorPool
  let imagesDescriptorSet: VkDescriptorSet

  static let maxSize: UInt32 = 65536
  private var recycledSlots: Set<UInt32> = []
  private var currentIndex: UInt32 = 0

  init(
    on device: GraphicsDevice, globalDescriptorSetLayout: VkDescriptorSetLayout,
    imagesDescriptorSetLayout: VkDescriptorSetLayout
  ) {
    self.device = device
    (self.imagesDescriptorPool, self.imagesDescriptorSet) = createImagesDescriptorSet(
      on: device, imagesDescriptorSetLayout)
  }

  private func createIndex() -> UInt32 {
    if let availableSlot = recycledSlots.popFirst() {  // well its random index, but who care
      return availableSlot
    }

    defer {
      currentIndex += 1
    }
    return currentIndex
  }

  func register(_ texture: Texture) {
    let index = createIndex()
    print("index = \(index)")
    let imageInfo = Box(VkDescriptorImageInfo()) {
      $0.imageView = texture.imageView
      $0.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
    }

    var writeSet = VkWriteDescriptorSet(
      sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
      pNext: nil,
      dstSet: self.imagesDescriptorSet,
      dstBinding: 0,
      dstArrayElement: index,
      descriptorCount: 1,
      descriptorType: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
      pImageInfo: imageInfo.ptr,
      pBufferInfo: nil,
      pTexelBufferView: nil
    )
    vkUpdateDescriptorSets(device.handle, 1, &writeSet, 0, nil)
  }

  // destroy?
}

private func createImagesDescriptorSet(
  on device: GraphicsDevice, _ imagesDescriptorSetLayout: VkDescriptorSetLayout
) -> (VkDescriptorPool, VkDescriptorSet) {
  // MARKER: Pools
  let poolSize1 = CArray([
    VkDescriptorPoolSize(
      type: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, descriptorCount: TextureRegistry.maxSize)
  ])

  var poolCi1 = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    pNext: nil,
    flags: VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT.u32,
    maxSets: 1,
    poolSizeCount: poolSize1.count,
    pPoolSizes: poolSize1.ptr
  )

  var pool: VkDescriptorPool?
  vkCreateDescriptorPool(device.handle, &poolCi1, nil, &pool).unwrap()

  // MARKER: Allocation
  let layout2 = Box(optional: imagesDescriptorSetLayout)

  let descriptorCounts = Box(TextureRegistry.maxSize)

  let ci2Next = Box(VkDescriptorSetVariableDescriptorCountAllocateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO
    $0.descriptorSetCount = 1
    $0.pDescriptorCounts = descriptorCounts.ptr
  }

  var ci2 = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    pNext: ci2Next.raw,
    descriptorPool: pool,
    descriptorSetCount: 1,
    pSetLayouts: layout2.mut
  )

  var descriptotSet: VkDescriptorPool?
  vkAllocateDescriptorSets(device.handle, &ci2, &descriptotSet).unwrap()

  return (pool!, descriptotSet!)
}
