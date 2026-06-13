/// store node index

import Vulkan

public final class Renderer {
    let context: SurfaceContext
    let swapchainImageFormat: Format
    let swapchainImageColorSpace: ColorSpaceKHR
    let pipelines: Pipelines
    var swapchain: SwapchainKHR

    var swapchainImages: [Image]
    var swapchainImageViews: [ImageView]

    var frameResources: [FrameResource] = []
    var currentFrameResource: FrameResource {
        frameResources[currentFrameInFlightIndex]
    }
    var lastFrameResource: FrameResource {
        frameResources[(currentFrameInFlightIndex + Self.maxFrameInFlightCount - 1) % Self.maxFrameInFlightCount]
    }

    let releaseQueue: ReleaseQueue = ReleaseQueue()

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

        self.swapchainImageFormat = .b8g8r8a8Unorm
        self.swapchainImageColorSpace = .srgbNonlinear

        // for surfaceFormat in formats {
            // let properties = physicalDevice.getFormatProperties(format: surfaceFormat.format)
            // print("\(surfaceFormat.format) in \(surfaceFormat.colorSpace):")
            // print(" - buffer: \(properties.bufferFeatures)")
            // print(" - linearTiling: \(properties.linearTilingFeatures)")
            // print(" - optimalTiling: \(properties.optimalTilingFeatures)")
            // print()
        // }

        let extent =
            if caps.currentExtent.width == UInt32.max {
                Extent2D(width: initialSize.x, height: initialSize.y)
            } else {
                caps.currentExtent
            }

        let (swapchain, images, views) = try Self.recreateSwapchain(
            device: device, surface: surface, caps: caps, imageFormat: swapchainImageFormat,
            colorspace: swapchainImageColorSpace, extent: extent)
        self.swapchain = swapchain
        self.swapchainImages = images
        self.swapchainImageViews = views

        self.width = extent.width
        self.height = extent.height

        let pipelines = try Pipelines(
            compatibleWith: swapchain, format: swapchainImageFormat, extent: extent, context: context)
        self.pipelines = pipelines
        self.frameResources = try (0..<Self.maxFrameInFlightCount).map { i throws(Vulkan.Result) in
            try FrameResource(index: i, context: context, pipelines: pipelines)
        }
    }

    // temporary api
    public func updateNodes(_ nodes: [RenderNode]) {
        for node in nodes {
            currentFrameResource.renderNodeStorage.update(
                node: node, shapeGroupStorage: currentFrameResource.shapeGroupStorage)
        }
        currentFrameResource.drawListStorage.write(
            nodes.map(\.id), renderNodeStorage: currentFrameResource.renderNodeStorage)
    }

    public func isWaitingForImage() throws -> Bool {
        do {
            try context.device.waitForFences(
                fences: [currentFrameResource.everythingCompletedFence], waitAll: true, timeout: 0)
            return false
        } catch {
            if error == .timeout {
                return true
            }
            throw error
        }
    }

    public func waitForImage(reset: Bool = true) throws {
        try context.device.waitForFences(
            fences: [currentFrameResource.everythingCompletedFence], waitAll: true,
            timeout: UInt64.max)
        if reset {
            try context.device.resetFences(fences: [currentFrameResource.everythingCompletedFence])
        }
    }

    public func waitLastImage(reset: Bool = true) throws {
        let res = lastFrameResource
        try context.device.waitForFences(
            fences: [res.everythingCompletedFence], waitAll: true, timeout: UInt64.max)
        if reset {
            try context.device.resetFences(fences: [res.everythingCompletedFence])
        }
    }

    public func render(nodeCount renderNodeCount: UInt32) throws {
        try self.waitForImage()
        let res = currentFrameResource
        res.releaseQueue.flush()
        self.releaseQueue.flush()
        currentFrameInFlightIndex = (currentFrameInFlightIndex + 1) % Self.maxFrameInFlightCount

        let imageIndex = try context.device.acquireNextImage2KHR(
            .init(
                swapchain: swapchain, timeout: UInt64.max,
                semaphore: res.imageAvailableSemaphore, deviceMask: 1
            )
        )

        try recordCommands(
            into: res.commandBuffer,
            image: swapchainImages[Int(imageIndex)],
            imageView: swapchainImageViews[Int(imageIndex)],
            renderNodeCount: renderNodeCount,
            frameResource: res
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

        try context.graphicsQueue.submit2(
            submits: [graphicsSubmit], fence: res.everythingCompletedFence)

        try context.graphicsQueue.presentKHR(
            .init(
                waitSemaphores: [res.renderCompletedSemaphore],
                swapchains: [swapchain],
                imageIndices: [imageIndex],
            )
        )

    }

    private func recordCommands(
        into cmd: CommandBuffer,
        image: Image,
        imageView: ImageView,
        renderNodeCount: UInt32,
        frameResource: FrameResource
    ) throws {
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
                    x: 0,
                    y: 0,
                    width: Float(self.width),
                    height: Float(self.height),
                    minDepth: 0,
                    maxDepth: 1
                )
            ])
        cmd.setScissor(
            firstScissor: 0,
            scissors: [
                .init(offset: .zero, extent: Extent2D(width: self.width, height: self.height))
            ]
        )

        let viewMatrix = Affine.identity.scaled(x: 2 / Float(self.width), y: 2 / Float(self.height))
        // let viewport = (self.width, self.height)
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
                        aspectMask: .color,
                        baseMipLevel: 0,
                        levelCount: 1,
                        baseArrayLayer: 0,
                        layerCount: 1
                    ),
                )
            ]))

        try cmd.end()
    }

    public func resize(w: UInt32, h: UInt32) throws {
        self.width = w
        self.height = h
        try recreateSwapchain(extent: Extent2D(width: w, height: h))
    }

    func recreateSwapchain(extent: Extent2D) throws(Vulkan.Result) {
        let caps = try context.physicalDevice.getSurfaceCapabilitiesKHR(surface: context.surface)
        nonisolated(unsafe) let prev = self.swapchain
        let previousSwapchainImageViews = self.swapchainImageViews
        (swapchain, swapchainImages, swapchainImageViews) = try Self.recreateSwapchain(
            device: context.device,
            surface: context.surface,
            caps: caps,
            imageFormat: swapchainImageFormat,
            colorspace: swapchainImageColorSpace,
            extent: extent.clamped(from: caps.minImageExtent, to: caps.maxImageExtent),
            previous: prev
        )

        self.releaseQueue.schedule(in: Self.maxFrameInFlightCount + 1) {
            for view in previousSwapchainImageViews {
                view.destroy()
            }
            prev.destroyKHR()
        }
    }

    private static func recreateSwapchain(
        device: Device, surface: SurfaceKHR, caps: SurfaceCapabilitiesKHR, imageFormat: Format,
        colorspace: ColorSpaceKHR, extent: Extent2D, previous: SwapchainKHR? = nil
    ) throws(Vulkan.Result) -> (SwapchainKHR, [Image], [ImageView]) {
        let swapchain = try device.createSwapchainKHR(
            .init(
                surface: surface,
                minImageCount: caps.minImageCount,
                imageFormat: imageFormat,
                imageColorSpace: colorspace,
                imageExtent: extent,
                imageArrayLayers: 1,
                imageUsage: .colorAttachment,
                imageSharingMode: .exclusive,
                preTransform: caps.currentTransform,
                compositeAlpha: {
                    #if os(Linux)  // wayland
                        .preMultiplied
                    #else
                        .opaque
                    #endif
                }(),
                presentMode: .fifo,
                clipped: true,
                oldSwapchain: previous
            )
        )
        let swapchainImages = try swapchain.getImagesKHR()
        do {
            let swapchainImageViews = try swapchainImages.map { image in
                try device.createImageView(
                    .init(
                        image: image, viewType: .type2d, format: imageFormat,
                        components: .init(r: .r, g: .g, b: .b, a: .a),
                        subresourceRange: .init(
                            aspectMask: .color, baseMipLevel: 0, levelCount: 1,
                            baseArrayLayer: 0, layerCount: 1
                        )
                    )
                )
            }

            return (swapchain, swapchainImages, swapchainImageViews)
        } catch {
            throw error as! Vulkan.Result
        }
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

    let releaseQueue: ReleaseQueue = ReleaseQueue()

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
