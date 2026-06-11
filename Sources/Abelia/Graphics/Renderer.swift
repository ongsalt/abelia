/// store node index

import Vulkan

public final class Renderer {
    let context: SurfaceContext
    let imageFormat: Format
    let imageColorSpace: ColorSpaceKHR
    let pipelines: Pipelines
    let swapchain: SwapchainKHR

    var swapchainImages: [Image]
    var swapchainImageViews: [ImageView]

    var frameResources: [FrameResource] = []
    static let maxFrameInFlightCount = 2
    private var currentFrameInFlightIndex: Int = 0

    var width: UInt32
    var height: UInt32

    public init(context: SurfaceContext, initialSize: SIMD2<UInt32> = SIMD2(800, 600)) throws(Vulkan
        .Result)
    {
        self.context = context
        let physicalDevice = context.physicalDevice
        let device = context.device
        let surface = context.surface

        let caps = try physicalDevice.getSurfaceCapabilitiesKHR(surface: surface)
        let formats = try physicalDevice.getSurfaceFormatsKHR(surface: surface)

        let imageFormat: Format = .b8g8r8a8Srgb
        self.imageFormat = imageFormat
        self.imageColorSpace = .srgbNonlinear

        let extent =
            if caps.currentExtent.width == UInt32.max {
                Extent2D(width: initialSize.x, height: initialSize.y)
            } else {
                caps.currentExtent.clamped(from: caps.minImageExtent, to: caps.maxImageExtent)
            }

        self.swapchain = try device.createSwapchainKHR(
            .init(
                surface: surface, minImageCount: caps.minImageCount, imageFormat: imageFormat,
                imageColorSpace: imageColorSpace,
                imageExtent: extent,
                imageArrayLayers: 1,
                imageUsage: .colorAttachment, imageSharingMode: .exclusive,
                preTransform: caps.currentTransform,
                compositeAlpha: {
                    #if os(Linux)  // wayland
                        .preMultiplied
                    #else
                        .opaque
                    #endif
                }(),
                presentMode: .fifo, clipped: true
            )
        )

        self.swapchainImages = try swapchain.getImagesKHR()
        do {
            self.swapchainImageViews = try self.swapchainImages.map { image in
                try device.createImageView(
                    .init(
                        image: image, viewType: .type2d, format: imageFormat,
                        components: .init(r: .r, g: .g, b: .b, a: .a),
                        subresourceRange: .init(
                            aspectMask: .color, baseMipLevel: 0, levelCount: 1,
                            baseArrayLayer: 0, layerCount: 1
                        )))
            }
        } catch {
            throw error as! Vulkan.Result
        }

        self.width = extent.width
        self.height = extent.height

        let pipelines = try Pipelines(
            compatibleWith: swapchain, format: imageFormat, extent: extent, context: context)
        self.pipelines = pipelines
        self.frameResources = try (0..<Self.maxFrameInFlightCount).map { i throws(Vulkan.Result) in
            try FrameResource(index: i, context: context, pipelines: pipelines)
        }
    }

    // temporary api
    public func updateNodes(_ nodes: [RenderNode]) {
        let res = frameResources[currentFrameInFlightIndex]
        for node in nodes {
            res.renderNodeStorage.update(
                node: node, shapeGroupStorage: res.shapeGroupStorage)
        }
        res.drawListStorage.write(nodes.map(\.id), renderNodeStorage: res.renderNodeStorage)
    }

    // public func updateFrameData(updator: (RenderNodeStorage) -> Void) {
    //     let frameData = frameResources[currentFrameInFlightIndex]
    //     updator(frameData.renderNodeStorage)
    // }

    public func render() throws {
        let res = frameResources[currentFrameInFlightIndex]

        let imageIndex = try context.device.acquireNextImage2KHR(
            .init(
                swapchain: swapchain, timeout: UInt64.max,
                semaphore: res.imageAvailableSemaphore, deviceMask: 1
            )
        )

        try recordCommands(
            into: res.commandBuffer,
            image: swapchainImages[Int(imageIndex)],
            imageView: swapchainImageViews[Int(imageIndex)]
        )

        let graphicsSubmit = SubmitInfo2(
            waitSemaphoreInfos: [
                .init(
                    semaphore: res.imageAvailableSemaphore, value: 0,
                    stageMask: .colorAttachmentOutput, deviceIndex: 0
                )
            ],
            commandBufferInfos: [.init(commandBuffer: res.commandBuffer, deviceMask: 0)],
            signalSemaphoreInfos: [
                .init(
                    semaphore: res.renderCompletedSemaphore, value: 0,
                    stageMask: .colorAttachmentOutput, deviceIndex: 0
                )
            ]
        )

        try context.graphicsQueue.submit2(submits: [graphicsSubmit])

        try context.graphicsQueue.presentKHR(
            .init(
                waitSemaphores: [res.renderCompletedSemaphore],
                swapchains: [swapchain],
                imageIndices: [imageIndex],
            )
        )

    }

    private func recordCommands(into cmd: CommandBuffer, image: Image, imageView: ImageView) throws
    {
        try cmd.reset()
        try cmd.begin()

        cmd.pipelineBarrier2(
            .init(imageMemoryBarriers: [
                .init(
                    srcStageMask: .topOfPipe,
                    srcAccessMask: .none,
                    dstStageMask: .colorAttachmentOutput,
                    dstAccessMask: [.colorAttachmentWrite, .colorAttachmentRead],
                    oldLayout: .undefined,
                    newLayout: .colorAttachmentOptimal,
                    srcQueueFamilyIndex: 0,
                    dstQueueFamilyIndex: 0,
                    image: image,
                    subresourceRange: .init(
                        aspectMask: .color, baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0,
                        layerCount: 1),
                )
            ]))

        cmd.beginRendering(
            .init(
                renderArea: .init(
                    offset: .zero, extent: Extent2D(width: self.width, height: self.height)),
                layerCount: 1, viewMask: 0,
                colorAttachments: [
                    .init(
                        imageView: imageView, imageLayout: .colorAttachmentOptimal,
                        resolveMode: .none, resolveImageView: nil,
                        resolveImageLayout: .undefined, loadOp: .clear,
                        storeOp: .store,
                        clearValue: .init(color: .init(float32: (0.0, 0.0, 0.0, 0.1))))
                ]))

        cmd.bindPipeline(pipelineBindPoint: .graphics, pipeline: pipelines.compositionPipeline)
        cmd.setViewport(
            firstViewport: 0,
            viewports: [
                .init(
                    x: 0, y: 0, width: Float(self.width), height: Float(self.height), minDepth: 0,
                    maxDepth: 1)
            ])
        cmd.setScissor(
            firstScissor: 0,
            scissors: [
                .init(offset: .zero, extent: Extent2D(width: self.width, height: self.height))
            ]
        )

        let viewport = (self.width, self.height)
        withUnsafeBytes(of: viewport) { viewportBuffer in
            cmd.pushConstants(
                layout: pipelines.compositionPipelineLayout, 
                stageFlags: [.vertex, .fragment], 
                offset: 0, 
                size:  UInt32(viewportBuffer.count), 
                values: viewportBuffer.baseAddress!
            )
        }

        cmd.draw(vertexCount: 6, instanceCount: 10, firstVertex: 0, firstInstance: 0)
        cmd.endRendering()

        cmd.pipelineBarrier2(
            .init(imageMemoryBarriers: [
                .init(
                    srcStageMask: .colorAttachmentOutput,
                    srcAccessMask: [.colorAttachmentWrite, .colorAttachmentRead],
                    dstStageMask: .bottomOfPipe,
                    dstAccessMask: .none,
                    oldLayout: .colorAttachmentOptimal,
                    newLayout: .presentSrcKHR,
                    srcQueueFamilyIndex: 0,
                    dstQueueFamilyIndex: 0,
                    image: image,
                    subresourceRange: .init(
                        aspectMask: .color, baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0,
                        layerCount: 1),
                )
            ]))

        try cmd.end()
    }
}
final class Pipelines {
    let compositionPipeline: Pipeline
    let compositionPipelineLayout: PipelineLayout
    let mainDescriptorSetLayout: DescriptorSetLayout
    // let renderNodeStorageDescriptorSet: DescriptorSet
    let descriptorPool: DescriptorPool

    init(
        compatibleWith swapchain: SwapchainKHR,
        format: Format,
        extent: Extent2D,
        context: borrowing SurfaceContext
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
                    // viewport size
                    .init(
                        stageFlags: [.vertex, .fragment], offset: 0,
                        size: UInt32(MemoryLayout<[2 of UInt32]>.size))
                    // view matrix?
                    // .init(stageFlags: [.vertex, .fragment], offset: 0, size: UInt32(MemoryLayout<[16 of Float]>.size))
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
                        x: 0, y: 0, width: Float(extent.width),
                        height: Float(extent.height), minDepth: 1, maxDepth: 1)
                ],
                scissors: [
                    .init(
                        offset: Offset2D(x: 0, y: 0),
                        extent: extent
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
        _ context: borrowing SurfaceContext
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
class FrameResource {
    let index: Int
    let commandPool: CommandPool
    let commandBuffer: CommandBuffer

    let renderCompletedSemaphore: Semaphore
    let imageAvailableSemaphore: Semaphore
    let everythingCompletedFence: Fence

    let mainDescriptorSet: DescriptorSet
    let renderNodeStorage: RenderNodeStorage
    let shapeGroupStorage: ShapeGroupStorage
    let drawListStorage: DrawListStorage

    init(index: Int, context: borrowing SurfaceContext, pipelines: borrowing Pipelines)
        throws(Vulkan.Result)
    {
        let commandPool = try context.device.createCommandPool(
            .init(flags: .resetCommandBuffer, queueFamilyIndex: context.graphicsFamilyIndex))
        let commandBuffer = try context.device.allocateCommandBuffers(
            .init(commandPool: commandPool, level: .primary, commandBufferCount: 1))

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

        self.index = index
        self.commandPool = commandPool
        self.commandBuffer = commandBuffer[0]
        self.renderCompletedSemaphore = try context.device.createSemaphore()
        self.imageAvailableSemaphore = try context.device.createSemaphore()
        self.everythingCompletedFence = try context.device.createFence(.init(flags: .signaled))
        self.mainDescriptorSet = mainDescriptorSet
        self.renderNodeStorage = renderNodeStorage
        self.shapeGroupStorage = shapeGroupStorage
        self.drawListStorage = drawListStorage
    }
}
