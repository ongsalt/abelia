@preconcurrency import CVMA
import Foundation
import Pointer

class CompositePipeline {
    let pipeline: VkPipeline
    let pipelineLayout: VkPipelineLayout
    let device: VkDevice

    init(
        state: VulkanState,
        textureRegistry: RenderTextureRegistry
    ) {
        let device = state.device
        let swapChain = state.swapChain
        self.device = device
        let vertexShader = Result {
            try Shader(filename: "composite.vert.spv", device: device)
        }.expect("Cannot create shader")
        let fragmentShader = Result {
            try Shader(filename: "composite.frag.spv", device: device)
        }.expect("Cannot create shader")

        var vertCi = VkPipelineShaderStageCreateInfo()
        vertCi.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
        vertCi.stage = VK_SHADER_STAGE_VERTEX_BIT
        vertCi.module = vertexShader.shaderModule
        let vertName = CString("main")
        vertCi.pName = vertName.ptr

        var fragCi = VkPipelineShaderStageCreateInfo()
        fragCi.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
        fragCi.stage = VK_SHADER_STAGE_FRAGMENT_BIT
        fragCi.module = fragmentShader.shaderModule
        let fragName = CString("main")
        fragCi.pName = fragName.ptr

        let shaderStages = [vertCi, fragCi]

        let bindingDescriptions = Pin([
            CompositeNodeVertexData.bindingDescriptions
        ])
        let attributeDescriptions = Pin(CompositeNodeVertexData.attributeDescriptions)

        let vertexInputCI = Box(VkPipelineVertexInputStateCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
            $0.vertexBindingDescriptionCount = bindingDescriptions.count
            $0.pVertexBindingDescriptions = bindingDescriptions.readonly
            $0.vertexAttributeDescriptionCount = attributeDescriptions.count
            $0.pVertexAttributeDescriptions = attributeDescriptions.readonly
        }

        let inputAssemblyCI = Box(VkPipelineInputAssemblyStateCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
            $0.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
            // $0.primitiveRestartEnable = false
        }

        // this can be changed
        let viewport = Box(
            VkViewport(
                x: 0,
                y: 0,
                width: Float(swapChain.extent.width),
                height: Float(swapChain.extent.height),
                minDepth: 0,
                maxDepth: 1
            ))

        let scissor = Box(
            VkRect2D(
                offset: VkOffset2D(x: 0, y: 0),
                extent: swapChain.extent
            ))

        let viewportCI = Box(VkPipelineViewportStateCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
            $0.viewportCount = 1
            $0.pViewports = viewport.readonly
            $0.scissorCount = 1
            $0.pScissors = scissor.readonly
        }

        let multisampleCI = Box(VkPipelineMultisampleStateCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
            $0.sampleShadingEnable = false
            $0.rasterizationSamples = VK_SAMPLE_COUNT_4_BIT
            $0.minSampleShading = 1.0  // Optional
            // $0.pSampleMask = nil  // Optional
            // $0.alphaToCoverageEnable = false  // Optional
            // $0.alphaToOneEnable = false  // Optional
        }

        let rasterizationCI = Box(VkPipelineRasterizationStateCreateInfo()) { rasterizer in
            rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
            rasterizer.depthClampEnable = false
            rasterizer.polygonMode = VK_POLYGON_MODE_FILL
            rasterizer.lineWidth = 1.0

            rasterizer.cullMode = VK_CULL_MODE_NONE.rawValue
        }

        let colorBlendAttachment = Box(VkPipelineColorBlendAttachmentState()) {
            $0.colorWriteMask = VkColorComponentFlags(
                VK_COLOR_COMPONENT_R_BIT.rawValue | VK_COLOR_COMPONENT_G_BIT.rawValue
                    | VK_COLOR_COMPONENT_B_BIT.rawValue | VK_COLOR_COMPONENT_A_BIT.rawValue
            )
            $0.blendEnable = true
            $0.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA
            $0.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
            $0.colorBlendOp = VK_BLEND_OP_ADD
            $0.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE
            // $0.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO
            $0.dstAlphaBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
            $0.alphaBlendOp = VK_BLEND_OP_ADD
        }

        let colorBlendingCI = Box(VkPipelineColorBlendStateCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
            $0.logicOpEnable = false
            $0.logicOp = VK_LOGIC_OP_COPY
            $0.attachmentCount = 1
            $0.pAttachments = colorBlendAttachment.readonly
            $0.blendConstants.0 = 0.0
            $0.blendConstants.1 = 0.0
            $0.blendConstants.2 = 0.0
            $0.blendConstants.3 = 0.0
        }

        // TODO: come back to this once we want more pushConstantRange

        // This one for screen size
        let pushConstantRange = Box(VkPushConstantRange()) {
            $0.stageFlags =
                VK_SHADER_STAGE_VERTEX_BIT.rawValue | VK_SHADER_STAGE_FRAGMENT_BIT.rawValue
            $0.size = UInt32(MemoryLayout<SIMD2<UInt32>>.size)
        }

        // let layoutBinding = Box(VkDescriptorSetLayoutBinding()) {
        //     $0.binding = 0
        //     $0.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
        //     $0.descriptorCount = 1  // how tf would i know,
        //     $0.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT.rawValue | VK_SHADER_STAGE_VERTEX_BIT.rawValue
        // }
        // var descriptorSetLayoutCI = with(VkDescriptorSetLayoutCreateInfo()) {
        //     $0.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
        //     $0.bindingCount = 1
        //     $0.pBindings = layoutBinding.readonly
        //     $0.pNext = bindingFlags.raw
        // }

        // let descriptorSetLayout = Box(VkDescriptorSetLayout(bitPattern: 0)) {
        //     vkCreateDescriptorSetLayout(vulkan.device, &descriptorSetLayoutCI, nil, &$0).unwrap()
        // }

        let setLayouts: Pin<VkDescriptorSetLayout?> = Pin([
            textureRegistry.descriptorSetLayout
                // VkDescriptorSetLayout(),
        ])
        var pipelineLayoutCI = with(VkPipelineLayoutCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
            $0.setLayoutCount = 1
            $0.pSetLayouts = setLayouts.readonly
            $0.pushConstantRangeCount = 1
            $0.pPushConstantRanges = pushConstantRange.readonly
        }

        let pipelineLayout = with(VkPipelineLayout(bitPattern: 0)) {
            vkCreatePipelineLayout(device, &pipelineLayoutCI, nil, &$0).expect(
                "Cannot create pipeline layout")
        }
        self.pipelineLayout = pipelineLayout!

        let dynamicStates = [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR]

        let imageFormat = Box(swapChain.surfaceFormat.format)
        // Dynamic rendering
        let renderingCI = Box(VkPipelineRenderingCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO
            $0.colorAttachmentCount = 1
            $0.pColorAttachmentFormats = imageFormat.readonly
            // $0.depthAttachmentFormat = depthFormat
        }

        let pipeline = shaderStages.withUnsafeBufferPointer { shaderStages in
            dynamicStates.withUnsafeBufferPointer { dynamicStates in
                let dynamicStateCI = Box(VkPipelineDynamicStateCreateInfo()) {
                    $0.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
                    $0.dynamicStateCount = 2
                    $0.pDynamicStates = dynamicStates.baseAddress
                }

                var pipelineCI = with(VkGraphicsPipelineCreateInfo()) {
                    $0.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
                    $0.pNext = renderingCI.raw
                    $0.layout = pipelineLayout!

                    $0.stageCount = UInt32(shaderStages.count)
                    $0.pStages = shaderStages.baseAddress
                    $0.pVertexInputState = vertexInputCI.readonly
                    $0.pInputAssemblyState = inputAssemblyCI.readonly
                    $0.pMultisampleState = multisampleCI.readonly
                    $0.pColorBlendState = colorBlendingCI.readonly
                    $0.pRasterizationState = rasterizationCI.readonly
                    $0.pViewportState = viewportCI.readonly
                    $0.pDynamicState = dynamicStateCI.readonly
                }

                let pipeline = with(VkPipeline(bitPattern: 0)) {
                    vkCreateGraphicsPipelines(device, nil, 1, &pipelineCI, nil, &$0).expect(
                        "Cannot create pipeline")
                }!

                return pipeline
            }
        }

        self.pipeline = pipeline
    }

    func bind(commandBuffer: VkCommandBuffer) {
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline)
    }
}
