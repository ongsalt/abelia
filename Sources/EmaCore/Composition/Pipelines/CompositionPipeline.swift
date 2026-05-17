@preconcurrency import CVulkan
import Pointer

public class CompositionPipeline {
  let handle: VkPipeline
  let layout: VkPipelineLayout
  let device: GraphicsDevice
  let descriptorSetLayouts: [2 of VkDescriptorSetLayout]

  let globalDescriptorPool: VkDescriptorPool
  let globalDescriptorSet: VkDescriptorSet

  private let defaultSampler: VkSampler

  init(
    device: GraphicsDevice,
    format: VkFormat,
    layerStorage: LayerStorage,
    layerStorageBuffer: GPUBuffer
  ) {
    self.device = device

    let format = format
    let shaderModule = ShaderModule(device: device, filename: "composite")!

    let shaderStages = createShaderStateCi([
      (shaderModule, "vertMain", VK_SHADER_STAGE_VERTEX_BIT),
      (shaderModule, "fragMain", VK_SHADER_STAGE_FRAGMENT_BIT),
    ])

    let dynamicStateCi = createDynamicStateCi()
    let vertexInputStateCi = createVertexInputStateCi(
      bindings: [VertexData.bindingDescription],
      attributes: VertexData.attributeDescriptions
    )
    let inputAssemblyStateCi = createInputAssemblyStateCi()
    let viewportStateCi = createViewportStateCi()
    let rasterizationStateCi = createRasterizationStateCi()
    let multisampleStateCi = createMultisampleStateCi()
    let colorBlendStateCi = createColorBlendStateCi()
    let (pipelineLayout, descriptorSetLayouts) = createCompositePipelineLayout(device: device)
    self.descriptorSetLayouts = descriptorSetLayouts
    self.layout = pipelineLayout
    // dynamic rendering
    let pipelineRenderingCi = createPipelineRenderingCi(format: format)

    var ci = VkGraphicsPipelineCreateInfo(
      sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
      pNext: pipelineRenderingCi.value.raw,
      flags: 0,
      stageCount: UInt32(shaderStages.value.count),
      pStages: shaderStages.value.ptr,
      pVertexInputState: vertexInputStateCi.value.ptr,
      pInputAssemblyState: inputAssemblyStateCi.ptr,
      pTessellationState: nil,
      pViewportState: viewportStateCi.value.ptr,
      pRasterizationState: rasterizationStateCi.value.ptr,
      pMultisampleState: multisampleStateCi.ptr,
      pDepthStencilState: nil,
      pColorBlendState: colorBlendStateCi.value.ptr,
      pDynamicState: dynamicStateCi.value.ptr,
      layout: pipelineLayout,
      renderPass: nil,
      subpass: 0,
      basePipelineHandle: nil,
      basePipelineIndex: 0
    )

    var pipeline: VkPipeline?
    vkCreateGraphicsPipelines(device.handle, nil, 1, &ci, nil, &pipeline).unwrap()
    self.handle = pipeline!

    self.defaultSampler = createDefaultSampler(device: device)

    (self.globalDescriptorPool, self.globalDescriptorSet) = createAndInitGlobalDescriptorSet(
      on: device, descriptorSetLayouts[0], defaultSampler: defaultSampler,
      layerStorageBuffer: layerStorageBuffer.handle)
  }
}

func createPipelineRenderingCi(format: VkFormat) -> WithDeps<Box<VkPipelineRenderingCreateInfo>> {
  let format = Box(format)
  let ci = VkPipelineRenderingCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
    pNext: nil,
    viewMask: 0,
    colorAttachmentCount: 1,
    pColorAttachmentFormats: format.ptr,
    depthAttachmentFormat: VK_FORMAT_UNDEFINED,  // unused
    stencilAttachmentFormat: VK_FORMAT_UNDEFINED  // unused
  )

  return Box(ci).addDeps(format)
}

private func createCompositePipelineLayout(device: GraphicsDevice) -> (
  VkPipelineLayout, [2 of VkDescriptorSetLayout]
) {
  let descriptorSet1Bindings = CArray([
    // default sampler
    VkDescriptorSetLayoutBinding(
      binding: 0,
      descriptorType: VK_DESCRIPTOR_TYPE_SAMPLER,
      descriptorCount: 1,
      stageFlags: VK_SHADER_STAGE_FRAGMENT_BIT.u32,
      pImmutableSamplers: nil
    ),

    // node storage
    VkDescriptorSetLayoutBinding(
      binding: 1,
      descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
      descriptorCount: 1,
      stageFlags: VK_SHADER_STAGE_FRAGMENT_BIT.u32,
      pImmutableSamplers: nil
    ),
  ])

  var descriptorSetLayout1CreateInfo =
    VkDescriptorSetLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      pNext: nil,
      flags: 0,
      bindingCount: descriptorSet1Bindings.count,
      pBindings: descriptorSet1Bindings.ptr
    )

  var descriptorSetLayout1: VkDescriptorSetLayout?
  vkCreateDescriptorSetLayout(
    device.handle, &descriptorSetLayout1CreateInfo, nil, &descriptorSetLayout1
  ).unwrap()

  // MARKER: descriptor indexing

  // for raster root + other texture
  let descriptorSet2Bindings = CArray([
    //
    VkDescriptorSetLayoutBinding(
      binding: 0,
      descriptorType: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
      descriptorCount: TextureRegistry.maxSize,  // the spec state minimum supported is 500k
      stageFlags: VK_SHADER_STAGE_FRAGMENT_BIT.u32,
      pImmutableSamplers: nil
    )
  ])

  let bindingFlags = Box(
    VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT.u32
      | VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT.u32
      | VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT.u32
      | VK_DESCRIPTOR_BINDING_UPDATE_UNUSED_WHILE_PENDING_BIT.u32
  )
  let bindingFlagsCi = Box(VkDescriptorSetLayoutBindingFlagsCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO_EXT
    $0.bindingCount = 1
    $0.pBindingFlags = bindingFlags.ptr
  }

  var descriptorSetLayout2CreateInfo =
    VkDescriptorSetLayoutCreateInfo(
      sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      pNext: bindingFlagsCi.ptr,
      // so we gonna have 1 big descriptor containing every rasterization root
      flags: VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT.u32,
      bindingCount: descriptorSet2Bindings.count,
      pBindings: descriptorSet2Bindings.ptr
    )

  var descriptorSetLayout2: VkDescriptorSetLayout?
  vkCreateDescriptorSetLayout(
    device.handle, &descriptorSetLayout2CreateInfo, nil, &descriptorSetLayout2
  ).unwrap()

  let descriptorSetLayouts: CArray<_> = [descriptorSetLayout1, descriptorSetLayout2]

  let pushConstantRange: Box<VkPushConstantRange> = Box(
    VkPushConstantRange(
      stageFlags: VK_SHADER_STAGE_VERTEX_BIT.u32 | VK_SHADER_STAGE_FRAGMENT_BIT.u32,
      offset: 0,
      // just screen size
      size: 2 * UInt32(MemoryLayout<Float>.size)
    )
  )

  var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    pNext: nil,
    flags: 0,
    setLayoutCount: descriptorSetLayouts.count,
    pSetLayouts: descriptorSetLayouts.ptr,
    pushConstantRangeCount: 1,
    pPushConstantRanges: pushConstantRange.ptr
  )

  var pipelineLayout: VkPipelineLayout?
  vkCreatePipelineLayout(device.handle, &pipelineLayoutInfo, nil, &pipelineLayout).unwrap()
  return (pipelineLayout!, [descriptorSetLayout1!, descriptorSetLayout2!])
}

func createRasterizationStateCi() -> WithDeps<Box<VkPipelineRasterizationStateCreateInfo>> {
  let ci = VkPipelineRasterizationStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0,
    depthClampEnable: false,
    rasterizerDiscardEnable: false,
    polygonMode: VK_POLYGON_MODE_FILL,
    cullMode: VK_CULL_MODE_NONE.u32,
    frontFace: VK_FRONT_FACE_CLOCKWISE,
    depthBiasEnable: false,
    depthBiasConstantFactor: 0,
    depthBiasClamp: 0,
    depthBiasSlopeFactor: 0,
    lineWidth: 1
  )

  return WithDeps(Box(ci))
}

func createDynamicStateCi() -> WithDeps<Box<VkPipelineDynamicStateCreateInfo>> {
  let dynamicStates = CArray([VK_DYNAMIC_STATE_SCISSOR, VK_DYNAMIC_STATE_VIEWPORT])
  let dynamicStateCi = Box(VkPipelineDynamicStateCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
    $0.pDynamicStates = dynamicStates.ptr
    $0.dynamicStateCount = dynamicStates.count
  }

  return dynamicStateCi.addDeps(dynamicStates)
}

func createVertexInputStateCi(
  bindings: [VkVertexInputBindingDescription],
  attributes: [VkVertexInputAttributeDescription],
) -> WithDeps<Box<VkPipelineVertexInputStateCreateInfo>> {
  let bindings = CArray(bindings)
  let attributes = CArray(attributes)
  let vertexInputStateCi = VkPipelineVertexInputStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0,
    vertexBindingDescriptionCount: bindings.count,
    pVertexBindingDescriptions: bindings.ptr,
    vertexAttributeDescriptionCount: attributes.count,
    pVertexAttributeDescriptions: attributes.ptr
  )

  return Box(vertexInputStateCi).addDeps(bindings).addDeps(attributes)
}

func createInputAssemblyStateCi() -> Box<VkPipelineInputAssemblyStateCreateInfo> {
  let ci = VkPipelineInputAssemblyStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0,
    topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
    primitiveRestartEnable: false
  )

  return Box(ci)
}

func createViewportStateCi() -> WithDeps<Box<VkPipelineViewportStateCreateInfo>> {
  // viewport and scissor can be set later
  let viewport = Box(VkViewport())
  let scissor = Box(VkRect2D())
  let ci = VkPipelineViewportStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0,
    viewportCount: 1,
    pViewports: viewport.ptr,
    scissorCount: 1,
    pScissors: scissor.ptr
  )

  return Box(ci).addDeps(viewport).addDeps(scissor)
}

func createMultisampleStateCi() -> Box<VkPipelineMultisampleStateCreateInfo> {
  let ci = VkPipelineMultisampleStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0,
    rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
    sampleShadingEnable: false,
    minSampleShading: 1.0,
    pSampleMask: nil,
    alphaToCoverageEnable: false,
    alphaToOneEnable: false
  )

  return Box(ci)
}

func createColorBlendStateCi() -> WithDeps<Box<VkPipelineColorBlendStateCreateInfo>> {
  let colorWriteMask =
    VK_COLOR_COMPONENT_R_BIT.rawValue | VK_COLOR_COMPONENT_G_BIT.rawValue
    | VK_COLOR_COMPONENT_B_BIT.rawValue | VK_COLOR_COMPONENT_A_BIT.rawValue
  let attachment = VkPipelineColorBlendAttachmentState(
    blendEnable: true,
    srcColorBlendFactor: VK_BLEND_FACTOR_SRC_ALPHA,
    dstColorBlendFactor: VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
    colorBlendOp: VK_BLEND_OP_ADD,
    srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE,
    dstAlphaBlendFactor: VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
    alphaBlendOp: VK_BLEND_OP_ADD,
    colorWriteMask: VkColorComponentFlags(colorWriteMask)
  )

  let attachments = CArray([attachment])
  let ci = Box(VkPipelineColorBlendStateCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
    $0.logicOpEnable = false
    $0.logicOp = VK_LOGIC_OP_COPY
    $0.attachmentCount = UInt32(attachments.count)
    $0.pAttachments = attachments.ptr
  }

  return ci.addDeps(attachments)
}

// this is ass
func createShaderStateCi(_ shaderModules: [(ShaderModule, String, VkShaderStageFlagBits)])
  -> WithDeps<CArray<VkPipelineShaderStageCreateInfo>>
{
  var cis: [VkPipelineShaderStageCreateInfo] = []
  var deps: [AnyObject] = []
  for (shaderModule, name, stage) in shaderModules {
    let name = CString(name)
    let ci = VkPipelineShaderStageCreateInfo(
      sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
      pNext: nil,
      flags: 0,
      stage: stage,
      module: shaderModule.handle,
      pName: name.ptr,
      pSpecializationInfo: nil  // ?
    )

    cis.append(ci)
    deps.append(name)
  }

  return WithDeps(CArray(cis), deps: deps)
}

func createAndInitGlobalDescriptorSet(
  on device: GraphicsDevice,
  _ globalDescriptorSetLayout: VkDescriptorSetLayout,
  defaultSampler: VkSampler,
  layerStorageBuffer: VkBuffer
) -> (VkDescriptorPool, VkDescriptorSet) {
  let poolSizes = CArray([
    VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_SAMPLER, descriptorCount: 1),
    VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, descriptorCount: 1),
  ])

  var poolCi = VkDescriptorPoolCreateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
    pNext: nil,
    flags: 0,
    maxSets: 2,
    poolSizeCount: poolSizes.count,
    pPoolSizes: poolSizes.ptr
  )

  var pool: VkDescriptorPool?
  vkCreateDescriptorPool(device.handle, &poolCi, nil, &pool).unwrap()

  let layout = Box(optional: globalDescriptorSetLayout)
  var ci = VkDescriptorSetAllocateInfo(
    sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
    pNext: nil,
    descriptorPool: pool,
    descriptorSetCount: 1,
    pSetLayouts: layout.ptr
  )

  var descriptotSet: VkDescriptorPool?
  vkAllocateDescriptorSets(device.handle, &ci, &descriptotSet).unwrap()

  // MARKER: actully init it, cuz it static

  let samplerInfo = Box(VkDescriptorImageInfo()) {
    $0.sampler = defaultSampler
  }

  let layerStorageInfo = Box(VkDescriptorBufferInfo()) {
    $0.buffer = layerStorageBuffer
    $0.offset = 0
    $0.range = VK_WHOLE_SIZE
  }

  var writeSets = [
    VkWriteDescriptorSet(
      sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
      pNext: nil,
      dstSet: descriptotSet,
      dstBinding: 0,
      dstArrayElement: 0,
      descriptorCount: 1,
      descriptorType: VK_DESCRIPTOR_TYPE_SAMPLER,
      pImageInfo: samplerInfo.ptr,
      pBufferInfo: nil,
      pTexelBufferView: nil
    ),
    VkWriteDescriptorSet(
      sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
      pNext: nil,
      dstSet: descriptotSet,
      dstBinding: 1,
      dstArrayElement: 0,
      descriptorCount: 1,
      descriptorType: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
      pImageInfo: nil,
      pBufferInfo: layerStorageInfo.ptr,
      pTexelBufferView: nil
    ),
  ]
  vkUpdateDescriptorSets(device.handle, UInt32(writeSets.count), &writeSets, 0, nil)

  return (pool!, descriptotSet!)
}

private func createDefaultSampler(device: GraphicsDevice) -> VkSampler {
  var ci = with(VkSamplerCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
    $0.magFilter = VK_FILTER_LINEAR
    $0.minFilter = VK_FILTER_LINEAR
    $0.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR
    $0.addressModeU = VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT
    $0.addressModeV = VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT
    $0.addressModeW = VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT

    // $0.unnormalizedCoordinates = true

    // $0.anisotropyEnable = VK_TRUE
  }

  var sampler: VkSampler?
  vkCreateSampler(device.handle, &ci, nil, &sampler).unwrap()

  return sampler!
}
