@preconcurrency import CVulkan
import Pointer

class TextureRegistry {
  let globalDescriptorPool: VkDescriptorPool
  let imagesDescriptorPool: VkDescriptorPool
  let globalDescriptorSet: VkDescriptorSet
  let imagesDescriptorSet: VkDescriptorSet

  init(
    on device: GraphicsDevice, globalDescriptorSetLayout: VkDescriptorSetLayout,
    imagesDescriptorSetLayout: VkDescriptorSetLayout
  ) {
    let (pools, sets) = createDescriptors(
      on: device, globalDescriptorSetLayout, imagesDescriptorSetLayout)

    globalDescriptorPool = pools[1]
    imagesDescriptorPool = pools[0]

    globalDescriptorSet = sets[0]
    imagesDescriptorSet = sets[1]
  }
}

private func createDescriptors(
  on device: GraphicsDevice, _ globalDescriptorSetLayout: VkDescriptorSetLayout,
  _ imagesDescriptorSetLayout: VkDescriptorSetLayout
) -> ([2 of VkDescriptorPool], [2 of VkDescriptorSet]) {
  // MARKER: Pools
  let poolSize1 = CArray([
    VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, descriptorCount: 65536)
  ])

  var poolCi1 = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    pNext: nil,
    flags: VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT.u32,
    maxSets: 1,
    poolSizeCount: poolSize1.count,
    pPoolSizes: poolSize1.ptr
  )

  let poolSize2 = CArray([
    VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_SAMPLER, descriptorCount: 1),
    VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount: 1),
  ])

  var poolCi2 = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    pNext: nil,
    flags: 0,
    maxSets: 2,
    poolSizeCount: poolSize2.count,
    pPoolSizes: poolSize2.ptr
  )

  var pool1: VkDescriptorPool?
  var pool2: VkDescriptorPool?
  vkCreateDescriptorPool(device.handle, &poolCi1, nil, &pool1).unwrap()
  vkCreateDescriptorPool(device.handle, &poolCi2, nil, &pool2).unwrap()

  // MARKER: Allocation
  let layout1 = Box(optional: globalDescriptorSetLayout)
  let layout2 = Box(optional: imagesDescriptorSetLayout)
  var ci1 = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    pNext: nil,
    descriptorPool: pool2,
    descriptorSetCount: 1,
    pSetLayouts: layout1.mut
  )

  let descriptorCounts = Box<UInt32>(65536)

  let ci2Next = Box(VkDescriptorSetVariableDescriptorCountAllocateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO
    $0.descriptorSetCount = 1
    $0.pDescriptorCounts = descriptorCounts.ptr
  }

  var ci2 = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    pNext: ci2Next.raw,
    descriptorPool: pool1,
    descriptorSetCount: 1,
    pSetLayouts: layout2.mut
  )

  var set1: VkDescriptorPool?
  var set2: VkDescriptorPool?
  vkAllocateDescriptorSets(device.handle, &ci1, &set1).unwrap()
  vkAllocateDescriptorSets(device.handle, &ci2, &set2).unwrap()

  return ([pool1!, pool2!], [set1!, set2!])
}
