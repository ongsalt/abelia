/// store node index

import Vulkan

public final class Renderer {
    let context: DeviceContext
    let pipelines: Pipelines

    private var frameResources: [RendererFrameResource]

    public var viewAffine: Affine = .identity
    public init(context: DeviceContext, maxFrameInFlightCount: Int) throws(Vulkan.Result) {
        self.context = context

        let pipelines = try Pipelines(
            format: .b8g8r8a8Unorm,
            // extent: context.extent,
            context: context
        )
        self.pipelines = pipelines
        self.frameResources = try (0..<maxFrameInFlightCount).map { i throws(Vulkan.Result) in
            try RendererFrameResource(index: i, context: context, pipelines: pipelines)
        }
    }

    // func render(nodes: [RenderNode], to texture: RenderTexture, frameIndex: Int) -> GPUTask<RenderTexture> {

    // }

    // temporary api
    public func createDrawTask(
        to image: Image,
        view: ImageView,
        frameIndex: Int,
        size: SIMD2<UInt32>,
        nodes: [RenderNode],
    ) throws -> GPUTask<()> {
        let currentFrameResource = frameResources[frameIndex]
        for node in nodes {
            currentFrameResource.renderNodeStorage.update(
                node: node, 
                shapeGroupStorage: currentFrameResource.shapeGroupStorage
            )
        }

        currentFrameResource.drawListStorage.write(
            nodes.filter({ !$0.hidden }).map(\.id), 
            renderNodeStorage: currentFrameResource.renderNodeStorage
        )

        let renderFinishedBarrier = ImageMemoryBarrier2(
            srcStageMask: .colorAttachmentOutput,
            srcAccessMask: [.colorAttachmentWrite, .colorAttachmentRead],
            dstStageMask: .fragmentShader,
            dstAccessMask: .shaderSampledRead,
            oldLayout: .colorAttachmentOptimal,
            newLayout: .shaderReadOnlyOptimal,
            srcQueueFamilyIndex: 0,
            dstQueueFamilyIndex: 0,
            image: image,
            subresourceRange: .init(
                aspectMask: .color,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1
            ),
        )

        return GPUTask(yielding: (), barriers: [renderFinishedBarrier]) {
            self.recordCommands(
                into: $0,
                image: image,
                imageView: view,
                renderNodeCount: UInt32(nodes.count),
                frameResource: currentFrameResource,
                size: size,
            )
        }
    }

    private func recordCommands(
        into cmd: CommandBuffer,
        image: Image,
        imageView: ImageView,
        renderNodeCount: UInt32,
        frameResource: RendererFrameResource,
        size: SIMD2<UInt32>,
    ) {
        cmd.beginRendering(
            RenderingInfo(
                renderArea: .init(offset: .zero, extent: Extent2D(width: size.x, height: size.y)),
                layerCount: 1,
                viewMask: 0,
                colorAttachments: [
                    .init(
                        imageView: imageView, imageLayout: .colorAttachmentOptimal,
                        resolveMode: .none, resolveImageView: nil,
                        resolveImageLayout: .undefined, loadOp: .clear,
                        storeOp: .store,
                        clearValue: .init(color: .init(float32: (0.0, 0.0, 0.0, 0.1)))
                    )
                ]
            )
        )

        cmd.bindPipeline(pipelineBindPoint: .graphics, pipeline: pipelines.compositionPipeline)
        cmd.setViewport(
            firstViewport: 0,
            viewports: [
                .init(
                    x: 0,
                    y: 0,
                    width: Float(size.x),
                    height: Float(size.y),
                    minDepth: 0,
                    maxDepth: 1
                )
            ])
        cmd.setScissor(
            firstScissor: 0,
            scissors: [
                .init(offset: .zero, extent: Extent2D(width: size.x, height: size.y))
            ]
        )

        let w = Float(size.x)
        let h = Float(size.y)
        let d: Float = 1000  // perspective depth in pixels; larger = weaker effect
        let projection = Affine().translated(x: -1, y: -1)
            .multiplied(
                by: Affine(
                    col0: SIMD4<Float>(2 / w, 0, 0, 0),
                    col1: SIMD4<Float>(0, 2 / h, 0, 0),
                    col2: SIMD4<Float>(0, 0, 0, 1 / d),  // z bleeds into w → perspective divide
                    col3: SIMD4<Float>(0, 0, 0, 1)
                ))
        let viewMatrix = projection.multiplied(by: viewAffine)
        // let viewport = (size.x, size.y)
        withUnsafeBytes(of: viewMatrix) { viewportBuffer in
            cmd.pushConstants(
                layout: pipelines.compositionPipelineLayout,
                stageFlags: [.vertex, .fragment],
                offset: 0,
                size: UInt32(viewportBuffer.count),
                values: viewportBuffer.baseAddress!
            )
        }

        cmd.bindDescriptorSets(
            pipelineBindPoint: .graphics,
            layout: pipelines.compositionPipelineLayout,
            firstSet: 0,
            descriptorSets: [frameResource.mainDescriptorSet]
        )

        cmd.draw(vertexCount: 6, instanceCount: renderNodeCount, firstVertex: 0, firstInstance: 0)
        cmd.endRendering()
    }
}
final class Pipelines {
    let compositionPipeline: Pipeline
    let compositionPipelineLayout: PipelineLayout
    let mainDescriptorSetLayout: DescriptorSetLayout
    let descriptorPool: DescriptorPool

    init(
        format: Format,
        context: borrowing DeviceContext
    )
        throws(Vulkan.Result)
    {
        let device = context.device
        let shaderModule = device.createShaderModule(filename: "composite")

        self.mainDescriptorSetLayout = try context.device.createDescriptorSetLayout(
            .init(bindings: [
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

            ])
        )

        self.compositionPipelineLayout = try device.createPipelineLayout(
            .init(
                setLayouts: [
                    mainDescriptorSetLayout
                ],
                pushConstantRanges: [
                    // viewport w, h
                    // .init(
                    //     stageFlags: [.vertex, .fragment], offset: 0,
                    //     size: UInt32(MemoryLayout<[2 of UInt32]>.size))
                    // view matrix?
                    .init(
                        stageFlags: [.vertex, .fragment], offset: 0,
                        size: UInt32(MemoryLayout<[16 of Float]>.size))
                ]
            )
        )

        let compositionPipelineCi = GraphicsPipelineCreateInfo(
            stages: [
                .init(stage: .vertex, module: shaderModule, name: "vsMain"),
                .init(stage: .fragment, module: shaderModule, name: "fsMain"),
            ],
            vertexInputState: .init(),
            inputAssemblyState: .init(topology: .triangleList, primitiveRestartEnable: false),
            viewportState: .init(
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
            rasterizationState: .init(
                depthClampEnable: false, rasterizerDiscardEnable: false, polygonMode: .fill,
                frontFace: .clockwise, depthBiasEnable: false, depthBiasConstantFactor: 0,
                depthBiasClamp: 0, depthBiasSlopeFactor: 0, lineWidth: 1
            ),
            multisampleState: .init(
                rasterizationSamples: .type1,
                sampleShadingEnable: false,
                minSampleShading: 1.0,
                alphaToCoverageEnable: false,
                alphaToOneEnable: false
            ),
            // depthStencilState: PipelineDepthStencilStateCreateInfo?,
            colorBlendState: .init(
                logicOpEnable: false,
                logicOp: .copy,
                attachments: [
                    .init(
                        blendEnable: true, srcColorBlendFactor: .srcAlpha,
                        dstColorBlendFactor: .oneMinusSrcAlpha, colorBlendOp: .add,
                        srcAlphaBlendFactor: .one, dstAlphaBlendFactor: .oneMinusSrcAlpha,
                        alphaBlendOp: .add, colorWriteMask: [.a, .r, .g, .b])
                ],
                blendConstants: (0, 0, 0, 0)
            ),
            dynamicState: .init(dynamicStates: [.scissor, .viewport]),
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

        let pipelines = try device.createGraphicsPipelines([compositionPipelineCi])
        self.compositionPipeline = pipelines[0]

        self.descriptorPool = try context.device.createDescriptorPool(
            .init(
                maxSets: 2,
                poolSizes: [
                    .init(type: .storageBuffer, descriptorCount: 2 * 3)
                    // .init(type: .sampledImage, descriptorCount: 1024),
                ]
            )
        )
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
}
struct RendererFrameResource {
    let mainDescriptorSet: DescriptorSet
    let renderNodeStorage: RenderNodeStorage
    let shapeGroupStorage: ShapeGroupStorage
    let drawListStorage: DrawListStorage

    init(index: Int, context: borrowing DeviceContext, pipelines: borrowing Pipelines)
        throws(Vulkan.Result)
    {
        let mainDescriptorSet = try pipelines.createMainDescriptorSet(context)
        let renderNodeStorage = try RenderNodeStorage(context: context)
        let shapeGroupStorage = try ShapeGroupStorage(context: context)
        let drawListStorage = try DrawListStorage(context: context)

        context.device.updateDescriptorSets(descriptorWrites: [
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 0,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: renderNodeStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 1,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: shapeGroupStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 2,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: drawListStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),

        ])

        self.mainDescriptorSet = mainDescriptorSet
        self.renderNodeStorage = renderNodeStorage
        self.shapeGroupStorage = shapeGroupStorage
        self.drawListStorage = drawListStorage
    }
}
