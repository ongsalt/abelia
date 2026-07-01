import Vulkan

final class Pipelines {
    let compositionPipeline: Pipeline
    let compositionPipelineLayout: PipelineLayout
    // let blurPipelineLayout: PipelineLayout
    // Device writable
    let mainDescriptorSetLayout: DescriptorSetLayout
    let descriptorPool: DescriptorPool

    // RenderTexture
    let textureDescriptorSetLayout: DescriptorSetLayout

    // 1 per app, like sampler
    let globalDescriptorSetLayout: DescriptorSetLayout

    init(
        format: Format,
        context: borrowing DeviceContext,
        frameInFlightCount: Int
    )
        throws(Vulkan.Result)
    {
        let device = context.device
        let mainShaderModule = device.createShaderModule(filename: "composite")
        // let blurShaderModule = device.createShaderModule(filename: "blur")

        self.mainDescriptorSetLayout = try context.device.createDescriptorSetLayout(
            DescriptorSetLayoutCreateInfo(
                bindings: [
                    // RenderNodeStorage
                    .init(
                        binding: 0,
                        descriptorType: .storageBuffer,
                        descriptorCount: 1,
                        stageFlags: [.fragment, .vertex]
                    ),
                    // ShapeGroupStorage
                    .init(
                        binding: 1,
                        descriptorType: .storageBuffer,
                        descriptorCount: 1,
                        stageFlags: [.fragment, .vertex]
                    ),
                    // DrawList
                    .init(
                        binding: 2,
                        descriptorType: .storageBuffer,
                        descriptorCount: 1,
                        stageFlags: [.vertex]
                    ),
                    // Blur region storage
                    .init(
                        binding: 3,
                        descriptorType: .storageBuffer,
                        stageFlags: [.vertex, .fragment]
                    ),
                    // Effect region storage
                    .init(
                        binding: 4,
                        descriptorType: .storageBuffer,
                        stageFlags: [.vertex, .fragment]
                    ),
                ]
            )
        )

        self.textureDescriptorSetLayout = try context.device.createDescriptorSetLayout(
            DescriptorSetLayoutCreateInfo(
                flags: .updateAfterBindPool,
                bindings: [
                    // Textures
                    .init(
                        binding: 0,
                        descriptorType: .sampledImage,
                        descriptorCount: 512 * 1024,
                        stageFlags: .fragment
                    )
                ]
            )
            .push(
                DescriptorSetLayoutBindingFlagsCreateInfo(
                    bindingFlags: [[.updateAfterBind, .partiallyBound]],
                )
            )
        )

        // TODO: merge this with main set layout
        self.globalDescriptorSetLayout = try context.device.createDescriptorSetLayout(
            DescriptorSetLayoutCreateInfo(
                bindings: [
                    DescriptorSetLayoutBinding(
                        binding: 0,
                        descriptorType: .sampler,
                        descriptorCount: 1,
                        stageFlags: .fragment
                    )
                ]
            )
        )

        self.descriptorPool = try context.device.createDescriptorPool(
            .init(
                flags: .updateAfterBind,
                maxSets: 2 + UInt32(frameInFlightCount),
                poolSizes: [
                    .init(type: .storageBuffer, descriptorCount: UInt32(frameInFlightCount) * 5),
                    .init(type: .sampledImage, descriptorCount: 512 * 1024),
                    .init(type: .sampler, descriptorCount: 4),
                ]
            )
        )

        let viewMatrixPushConstant = PushConstantRange(
            stageFlags: [.vertex, .fragment], offset: 0,
            size: UInt32(MemoryLayout<[16 of Float]>.size)
        )

        self.compositionPipelineLayout = try device.createPipelineLayout(
            .init(
                setLayouts: [
                    mainDescriptorSetLayout,
                    textureDescriptorSetLayout,
                    globalDescriptorSetLayout,
                ],
                pushConstantRanges: [viewMatrixPushConstant]
            )
        )

        // self.blurPipelineLayout = try device.createPipelineLayout(
        //     PipelineLayoutCreateInfo(
        //         setLayouts: [
        //             mainDescriptorSetLayout,
        //             textureDescriptorSetLayout,
        //             globalDescriptorSetLayout,
        //         ],
        //         pushConstantRanges: [viewMatrixPushConstant]
        //     )
        // )

        let compositionPipelineCi = GraphicsPipelineCreateInfo(
            stages: [
                .init(stage: .vertex, module: mainShaderModule, name: "vsMain"),
                .init(stage: .fragment, module: mainShaderModule, name: "fsMain"),
            ],
            vertexInputState: PipelineVertexInputStateCreateInfo(),
            inputAssemblyState: PipelineInputAssemblyStateCreateInfo(
                topology: .triangleList, primitiveRestartEnable: false),
            viewportState:
                .init(
                    viewports: [
                        .init(
                            x: 0, y: 0, width: 1000,
                            height: 1000, minDepth: 1, maxDepth: 1)
                    ],
                    scissors: [
                        .init(
                            offset: Offset2D(x: 0, y: 0),
                            extent: Extent2D(width: 1000, height: 1000)
                        )
                    ]
                ),
            rasterizationState: PipelineRasterizationStateCreateInfo(
                depthClampEnable: false, rasterizerDiscardEnable: false, polygonMode: .fill,
                frontFace: .clockwise, depthBiasEnable: false, depthBiasConstantFactor: 0,
                depthBiasClamp: 0, depthBiasSlopeFactor: 0, lineWidth: 1
            ),
            multisampleState: PipelineMultisampleStateCreateInfo(
                rasterizationSamples: .type1,
                sampleShadingEnable: false,
                minSampleShading: 1.0,
                alphaToCoverageEnable: false,
                alphaToOneEnable: false
            ),
            colorBlendState: PipelineColorBlendStateCreateInfo(
                logicOpEnable: false,
                logicOp: .noOp,
                attachments: [
                    PipelineColorBlendAttachmentState(
                        blendEnable: true, srcColorBlendFactor: .one,
                        dstColorBlendFactor: .oneMinusSrcAlpha, colorBlendOp: .add,
                        srcAlphaBlendFactor: .one, dstAlphaBlendFactor: .oneMinusSrcAlpha,
                        alphaBlendOp: .add, colorWriteMask: [.a, .r, .g, .b], )
                ],
                blendConstants: (0, 0, 0, 0)
            ),
            dynamicState: PipelineDynamicStateCreateInfo(dynamicStates: [.scissor, .viewport]),
            layout: compositionPipelineLayout,
            subpass: 0,
            basePipelineIndex: 0
        )
        .push(
            PipelineRenderingCreateInfo(
                viewMask: 0,
                colorAttachmentFormats: [format],
                depthAttachmentFormat: .undefined,
                stencilAttachmentFormat: .undefined
            )
        )

        // let effectPipelineCi = GraphicsPipelineCreateInfo(
        //     stages: [
        //         .init(stage: .vertex, module: blurShaderModule, name: "vsMain"),
        //         .init(stage: .fragment, module: blurShaderModule, name: "fsMain"),
        //     ],
        //     vertexInputState: PipelineVertexInputStateCreateInfo(),
        //     inputAssemblyState: PipelineInputAssemblyStateCreateInfo(
        //         topology: .triangleList,
        //         primitiveRestartEnable: false
        //     ),
        //     viewportState: PipelineViewportStateCreateInfo(),
        //     rasterizationState: PipelineRasterizationStateCreateInfo(
        //         depthClampEnable: false, rasterizerDiscardEnable: false, polygonMode: .fill,
        //         frontFace: .clockwise, depthBiasEnable: false, depthBiasConstantFactor: 0,
        //         depthBiasClamp: 0, depthBiasSlopeFactor: 0, lineWidth: 1
        //     ),
        //     multisampleState: PipelineMultisampleStateCreateInfo(
        //         rasterizationSamples: .type1,
        //         sampleShadingEnable: false,
        //         minSampleShading: 1.0,
        //         alphaToCoverageEnable: false,
        //         alphaToOneEnable: false
        //     ),
        //     colorBlendState: PipelineColorBlendStateCreateInfo(
        //         logicOpEnable: false,
        //         logicOp: .noOp,
        //         attachments: [
        //             PipelineColorBlendAttachmentState(
        //                 blendEnable: true, srcColorBlendFactor: .one,
        //                 dstColorBlendFactor: .oneMinusSrcAlpha, colorBlendOp: .add,
        //                 srcAlphaBlendFactor: .one, dstAlphaBlendFactor: .oneMinusSrcAlpha,
        //                 alphaBlendOp: .add, colorWriteMask: [.a, .r, .g, .b])
        //         ],
        //         blendConstants: (0, 0, 0, 0)
        //     ),
        //     dynamicState: PipelineDynamicStateCreateInfo(dynamicStates: [.scissor, .viewport]),
        //     layout: compositionPipelineLayout,
        //     subpass: 0,
        //     basePipelineIndex: 0
        // )
        // .push(
        //     PipelineRenderingCreateInfo(
        //         viewMask: 0,
        //         colorAttachmentFormats: [format],
        //         depthAttachmentFormat: .undefined,
        //         stencilAttachmentFormat: .undefined
        //     )
        // )

        let pipelines = try device.createGraphicsPipelines([compositionPipelineCi])
        self.compositionPipeline = pipelines[0]

    }

    func createMainDescriptorSet(
        _ context: borrowing DeviceContext
    )
        throws(Vulkan.Result) -> DescriptorSet
    {
        let descriptorSets = try context.device.allocateDescriptorSets(
            .init(
                descriptorPool: descriptorPool,
                setLayouts: [mainDescriptorSetLayout]
            )
        )

        return descriptorSets[0]
    }

    func createTextureDescriptorSet(
        _ context: borrowing DeviceContext
    )
        throws(Vulkan.Result) -> DescriptorSet
    {
        let descriptorSets = try context.device.allocateDescriptorSets(
            DescriptorSetAllocateInfo(
                descriptorPool: descriptorPool,
                setLayouts: [textureDescriptorSetLayout]
            )
        )

        return descriptorSets[0]
    }

    // both bilinear
    func createSamplerDescriptorSet(
        _ context: borrowing DeviceContext
    )
        throws(Vulkan.Result) -> DescriptorSet
    {
        let descriptorSets = try context.device.allocateDescriptorSets(
            DescriptorSetAllocateInfo(
                descriptorPool: descriptorPool,
                setLayouts: [globalDescriptorSetLayout]
            )
        )

        let sampler = try context.device.createSampler(
            SamplerCreateInfo(
                magFilter: .linear, minFilter: .linear,
                mipmapMode: .linear, addressModeU: .clampToEdge,
                addressModeV: .clampToEdge, addressModeW: .clampToEdge,
                mipLodBias: 0, anisotropyEnable: false, maxAnisotropy: 0,
                compareEnable: false, compareOp: .never, minLod: 0, maxLod: 0,
                borderColor: .floatOpaqueBlack, unnormalizedCoordinates: false
            ))
        // leak btw

        context.device.updateDescriptorSets(descriptorWrites: [
            WriteDescriptorSet(
                dstSet: descriptorSets[0], dstBinding: 0, dstArrayElement: 0,
                descriptorCount: 1, descriptorType: .sampler,
                imageInfo: [
                    DescriptorImageInfo(sampler: sampler, imageView: nil, imageLayout: .undefined)
                ],
                bufferInfo: [],
                texelBufferView: []
            )

        ])

        return descriptorSets[0]
    }
}
