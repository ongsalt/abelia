import Vulkan

public protocol SurfaceProtocol {
    associatedtype Texture: SurfaceTextureProtocol

    func configure(_ configuration: SurfaceConfiguration) throws

    // may block
    func acquireCurrentTexture(signalling semaphore: Semaphore) throws -> Texture
}

public protocol SurfaceTextureProtocol {
    var texture: ImageAndView { get }
    var renderCompletedSemaphore: Semaphore { get }
    var imageIndex: UInt32 { get }

    func preparePresent() -> GPUCommands
    func prepareRender() -> GPUCommands

    // call queue submit, implicitly wait for renderCompletedSemaphore: Semaphore
    func present() throws
}

public struct SurfaceConfiguration {
    public var device: DeviceContext
    public var width: UInt32
    public var height: UInt32
    public var imageFormat: Format
    public var colorSpace: ColorSpaceKHR
    public var useMailbox: Bool = false
}

extension SurfaceConfiguration {
    func onlySizeChanged(comparedTo other: borrowing SurfaceConfiguration) -> Bool {
        device === other.device
            && imageFormat == other.imageFormat
            && colorSpace == other.colorSpace
            && useMailbox == other.useMailbox
            && (width != other.width || height != other.height)
    }
}

extension DeviceContext {
    public func vulkanSurfaceConfig(width: UInt32, height: UInt32, mailbox: Bool = false) -> SurfaceConfiguration {
        // TODO: query surface config
        return SurfaceConfiguration(
            device: self,
            width: width,
            height: height,
            imageFormat: .b8g8r8a8Srgb,
            colorSpace: .srgbNonlinear,
            useMailbox: mailbox
        )
    }
}

// internal impl

struct ConfiguredSurfaceInfo {
    var width: UInt32
    var height: UInt32

    var availableWidth: UInt32
    var availableHeight: UInt32

    let associatedDevice: DeviceContext
    var swapchain: SwapchainKHR

    // swapchain images
    var images: [Image]
    var imageViews: [ImageView]
    // Per swapchain image (total texture we have)
    var renderFinishedSemaphores: [Semaphore]

    var lastConfiguration: SurfaceConfiguration
}

/// pls keep the window alive
public class Surface: SurfaceProtocol {
    let handle: SurfaceKHR
    let releaseQueue: ReleaseQueue = ReleaseQueue()
    var configuredInfo: ConfiguredSurfaceInfo?

    var device: Device {
        configuredInfo!.associatedDevice.device
    }

    init(_ handle: SurfaceKHR) {
        self.handle = handle
    }

    public func configure(_ configuration: SurfaceConfiguration) throws {
        if let c = self.configuredInfo,
            c.lastConfiguration.onlySizeChanged(comparedTo: configuration),
            c.availableWidth >= configuration.width,
            c.availableHeight >= configuration.height
        {
            let prevSize = (c.lastConfiguration.width, c.lastConfiguration.height)
            let currentSize = (configuration.width, configuration.height)
            Log.verbose(.general, "Reusing... swapchain \(prevSize) -> \(currentSize)")
            return
        }
        Log.info(.general, "Recreating swapchain \((configuration.width, configuration.height))")

        let caps = try configuration.device.physicalDevice.getSurfaceCapabilitiesKHR(
            surface: handle)

        let size = SIMD2(Float(configuration.width), Float(configuration.height)) * 1.2
        let clamped = Extent2D(width: UInt32(size.x), height: UInt32(size.y))
            .clamped(from: caps.minImageExtent, to: caps.maxImageExtent)
        let width = clamped.width
        let height = clamped.height

        nonisolated(unsafe) let prev = configuredInfo?.swapchain
        let previousSwapchainImageViews = configuredInfo?.imageViews
        let previousSemaphores = configuredInfo?.renderFinishedSemaphores  // tf i do with this

        let clock = ContinuousClock()
        let start = clock.now
        let (swapchain, swapchainImages, swapchainImageViews) = try Self.recreateSwapchain(
            device: configuration.device.device,
            surface: handle,
            caps: caps,
            imageFormat: configuration.imageFormat,
            colorspace: configuration.colorSpace,
            extent: clamped,
            useMailbox: configuration.useMailbox,
            previous: prev,
        )
        let time = (clock.now - start) / .milliseconds(1)
        Log.info(.compositor, "recreated swapchain in \(time)ms")

        var semaphores: [Semaphore] = []
        for _ in 0..<swapchainImages.count {
            semaphores.append(
                try configuration.device.device.createSemaphore()
            )
        }

        // everytime present is called
        self.releaseQueue.scheduleNextCycle {
            if let previousSwapchainImageViews {
                for view in previousSwapchainImageViews {
                    view.destroy()
                }
            }
            prev?.destroyKHR()
            if let previousSemaphores {
                for s in previousSemaphores {
                    s.destroy()
                }
            }
        }

        self.configuredInfo = ConfiguredSurfaceInfo(
            width: width,
            height: height,
            availableWidth: width,
            availableHeight: height,
            associatedDevice: configuration.device,
            swapchain: swapchain,
            images: swapchainImages,
            imageViews: swapchainImageViews,
            renderFinishedSemaphores: semaphores,
            lastConfiguration: configuration
        )
    }

    // TODO: return outofdate/invalid
    public func acquireCurrentTexture(signalling semaphore: Semaphore) throws
        -> some SurfaceTextureProtocol
    {
        guard let configuredInfo else {
            fatalError("Please call .configure first")
        }

        let index = try device.acquireNextImage2KHR(
            .init(
                swapchain: configuredInfo.swapchain,
                timeout: UInt64.max,
                semaphore: semaphore,
                deviceMask: 1
            )
        )

        return SurfaceTexture(
            texture: ImageAndView(
                image: configuredInfo.images[Int(index)],
                view: configuredInfo.imageViews[Int(index)]
            ),
            renderCompletedSemaphore: configuredInfo.renderFinishedSemaphores[Int(index)],
            releaseQueue: self.releaseQueue,
            queue: configuredInfo.associatedDevice.graphicsQueue,
            swapchain: configuredInfo.swapchain,
            imageIndex: index
        )
    }

    private static func recreateSwapchain(
        device: Device, surface: SurfaceKHR, caps: SurfaceCapabilitiesKHR, imageFormat: Format,
        colorspace: ColorSpaceKHR, extent: Extent2D, useMailbox: Bool = false,
        previous: SwapchainKHR? = nil
    ) throws(Vulkan.Result) -> (SwapchainKHR, [Image], [ImageView]) {
        var targetImageCount = caps.minImageCount + 1
        if caps.maxImageCount != 0 {
            targetImageCount = max(targetImageCount, caps.maxImageCount)
        }
        let swapchain = try device.createSwapchainKHR(
            .init(
                surface: surface,
                minImageCount: targetImageCount,
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
                presentMode: useMailbox ? .mailbox : .fifoRelaxed,
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

struct SurfaceTexture: SurfaceTextureProtocol {
    let texture: ImageAndView
    let renderCompletedSemaphore: Vulkan.Semaphore
    let releaseQueue: ReleaseQueue

    private let queue: Queue
    private let swapchain: SwapchainKHR
    public let imageIndex: UInt32

    init(
        texture: ImageAndView,
        renderCompletedSemaphore: Semaphore,
        releaseQueue: ReleaseQueue,
        queue: Queue,
        swapchain: SwapchainKHR,
        imageIndex: UInt32
    ) {
        self.texture = texture
        self.releaseQueue = releaseQueue
        self.renderCompletedSemaphore = renderCompletedSemaphore
        self.queue = queue
        self.swapchain = swapchain
        self.imageIndex = imageIndex
    }

    func prepareRender() -> GPUCommands {
        GPUCommands {
            // transition swapchain image to colorAttachmentOptimal
            $0.pipelineBarrier2(
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
                        image: texture.image,
                        subresourceRange: .init(
                            aspectMask: .color, baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0,
                            layerCount: 1),
                    )
                ])
            )
        }
    }

    func preparePresent() -> GPUCommands {
        GPUCommands {
            // transition to color attachment optimal
            $0.pipelineBarrier2(
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
                        image: texture.image,
                        subresourceRange: .init(
                            aspectMask: .color,
                            baseMipLevel: 0,
                            levelCount: 1,
                            baseArrayLayer: 0,
                            layerCount: 1
                        ),
                    )
                ])
            )
        }
    }

    func present() throws {
        self.releaseQueue.flush()
        try queue.presentKHR(
            .init(
                waitSemaphores: [renderCompletedSemaphore],
                swapchains: [swapchain],
                imageIndices: [imageIndex],
            )
        )
    }
}
