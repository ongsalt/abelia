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

        print(caps)
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

        self.pipelines = try Pipelines(
            compatibleWith: swapchain, format: imageFormat, extent: extent, context: context)
        self.frameResources = try (0..<Self.maxFrameInFlightCount).map { i throws(Vulkan.Result) in
            try FrameResource(index: i, context: context)
        }
    }

    public func render() throws {
        let device = context.device
        let res = frameResources[0]
        let cmd = res.commandBuffer

        print(self.width, self.height)
        let imageAcquiredSemaphore = try device.createSemaphore()

        let imageIndex = Int(
            try device.acquireNextImage2KHR(
                .init(
                    swapchain: swapchain, timeout: UInt64.max,
                    semaphore: imageAcquiredSemaphore, deviceMask: 1)))

        let image = swapchainImages[imageIndex]
        let imageView = swapchainImageViews[imageIndex]

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
        cmd.draw(vertexCount: 3, instanceCount: 1, firstVertex: 0, firstInstance: 0)
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

        try context.graphicsQueue.submit2(submits: [
            .init(
                waitSemaphoreInfos: [
                    .init(
                        semaphore: imageAcquiredSemaphore, value: 0,
                        stageMask: .colorAttachmentOutput, deviceIndex: 0)
                ],
                commandBufferInfos: [.init(commandBuffer: cmd, deviceMask: 0)],
                signalSemaphoreInfos: [
                    .init(semaphore: res.renderCompletedSemaphore, value: 0, stageMask: .colorAttachmentOutput, deviceIndex: 0)
                ]
            )
        ])

        try context.graphicsQueue.presentKHR(
            .init(
                waitSemaphores: [res.renderCompletedSemaphore], swapchains: [swapchain],
                imageIndices: [UInt32(imageIndex)],
            ))

    }
}
final class Pipelines {
    let compositionPipeline: Pipeline

    init(
        compatibleWith swapchain: SwapchainKHR,
        format: Format,
        extent: Extent2D,
        context: borrowing SurfaceContext
    )
        throws(Vulkan.Result)
    {
        let device = context.device
        let shaderModule = device.createShaderModule(filename: "triangle")

        // let descriptorSetLayout = try device.createDescriptorSetLayout(.init(bindings: []))
        let layout = try device.createPipelineLayout(
            .init(
                setLayouts: [],
                pushConstantRanges: []
            )
        )

        let compositionPipelineCi = GraphicsPipelineCreateInfo(
            stages: [
                .init(stage: .vertex, module: shaderModule, name: "vertMain"),
                .init(stage: .fragment, module: shaderModule, name: "fragMain"),
            ],
            vertexInputState: .init(
                vertexBindingDescriptions: [],
                vertexAttributeDescriptions: []
            ),
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
            layout: layout,
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
    }
}
struct FrameResource {
    let index: Int
    let commandPool: CommandPool
    let commandBuffer: CommandBuffer
    let renderCompletedSemaphore: Semaphore
    let everythingCompletedFence: Fence
}
extension FrameResource {
    init(index: Int, context: borrowing SurfaceContext) throws(Vulkan.Result) {
        let pool = try context.device.createCommandPool(
            .init(flags: .resetCommandBuffer, queueFamilyIndex: context.graphicsFamilyIndex))
        let buffer = try context.device.allocateCommandBuffers(
            .init(commandPool: pool, level: .primary, commandBufferCount: 1))

        let fence = try context.device.createFence(.init(flags: .signaled))
        let semaphore = try context.device.createSemaphore()

        self.init(
            index: index, commandPool: pool, commandBuffer: buffer[0],
            renderCompletedSemaphore: semaphore, everythingCompletedFence: fence)
    }
}
