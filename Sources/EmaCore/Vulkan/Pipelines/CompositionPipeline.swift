@preconcurrency import CVulkan
import Pointer

public class CompositionPipeline {
  let handle: VkPipeline
  let device: GraphicsDevice

  init(device: GraphicsDevice, swapchain: borrowing Swapchain) {
    self.device = device
    handle = createCompositionPipeline(device: device, format: swapchain.imageFormat)
  }
}

private func createCompositionPipeline(
  device: GraphicsDevice,
  format: VkFormat
) -> VkPipeline {
  let shaderModule = ShaderModule(device: device, filename: "composite")!

  let shaderStages = createShaderStateCi([
    (shaderModule, "vertMain", VK_SHADER_STAGE_VERTEX_BIT),
    (shaderModule, "fragMain", VK_SHADER_STAGE_FRAGMENT_BIT),
  ])

  let dynamicStateCi = createDynamicStateCi()
  let vertexInputStateCi = createVertexInputStateCi(
    bindings: [
      // .init(binding: UInt32, stride: UInt32, inputRate: VkVertexInputRate)
    ], 
    attributes: [
      // .init(
      //   location: UInt32, binding: UInt32, format: VkFormat, offset: UInt32
      // )
    ]
  )
  let inputAssemblyStateCi = createInputAssemblyStateCi()
  let viewportStateCi = createViewportStateCi()
  let rasterizationStateCi = createRasterizationStateCi()
  let multisampleStateCi = createMultisampleStateCi()
  let colorBlendStateCi = createColorBlendStateCi()
  let pipelineLayout = createCompositePipelineLayout(device: device)
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
  return pipeline!
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

private func createCompositePipelineLayout(device: GraphicsDevice) -> VkPipelineLayout {
  var pipelineLayoutInfo = VkPipelineLayoutCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    pNext: nil,
    flags: 0,
    setLayoutCount: 0,
    pSetLayouts: nil,
    pushConstantRangeCount: 0,
    pPushConstantRanges: nil
  )

  var pipelineLayout: VkPipelineLayout?
  vkCreatePipelineLayout(device.handle, &pipelineLayoutInfo, nil, &pipelineLayout).unwrap()
  return pipelineLayout!
}

func createRasterizationStateCi() -> WithDeps<Box<VkPipelineRasterizationStateCreateInfo>> {
  let ci = VkPipelineRasterizationStateCreateInfo(
    sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    pNext: nil,
    flags: 0,
    depthClampEnable: false,
    rasterizerDiscardEnable: false,
    polygonMode: VK_POLYGON_MODE_FILL,
    cullMode: VK_CULL_MODE_BACK_BIT.u32,  // should be none?
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
    blendEnable: false,
    srcColorBlendFactor: VK_BLEND_FACTOR_ZERO,
    dstColorBlendFactor: VK_BLEND_FACTOR_ZERO,
    colorBlendOp: VK_BLEND_OP_ADD,
    srcAlphaBlendFactor: VK_BLEND_FACTOR_ZERO,
    dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO,
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
