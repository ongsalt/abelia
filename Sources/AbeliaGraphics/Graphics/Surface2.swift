import Vulkan

public struct SurfaceConfiguration2: Sendable {
    public var width: UInt32
    public var height: UInt32
    public var imageFormat: Format = .b8g8r8a8Srgb
    public var colorSpace: ColorSpaceKHR = .srgbNonlinear
    public var presentMode: PresentMode = .vsync
    public var frameInFlight: Int = 2

    public init(
        width: UInt32, height: UInt32, imageFormat: Format = .b8g8r8a8Srgb,
        colorSpace: ColorSpaceKHR = .srgbNonlinear, presentMode: PresentMode = .vsync,
        frameInFlight: Int = 2
    ) {
        self.width = width
        self.height = height
        self.imageFormat = imageFormat
        self.colorSpace = colorSpace
        self.presentMode = presentMode
        self.frameInFlight = frameInFlight
    }
    func onlySizeChanged(comparedTo other: SurfaceConfiguration2) -> Bool {
        imageFormat == other.imageFormat
            && colorSpace == other.colorSpace
            && presentMode == other.presentMode
            && frameInFlight == other.frameInFlight
            && (width != other.width || height != other.height)
    }
}

public enum PresentMode: Sendable {
    case vsync
    case mailbox
}

public enum SurfaceAcquireError: Error {
    case outOfDate
    case idk(any Error)
}

/// we can render into the image directly both on dxgi and vulkan wsi

public protocol Surface2: AnyObject {
    associatedtype SurfaceImage: SurfaceImageProtocol

    /// cpu side wait until we can record render command (with pacing)
    /// DXGI: wait until frame queued < max frame latency, (wait the timeline)
    /// vulkan wsi: fence maybe
    func wait()

    // might throws -> outOfDate
    func acquire() throws(SurfaceAcquireError) -> SurfaceImage

    /// resize also go through this
    func configure(_ configuration: SurfaceConfiguration2)

    /// get predicted next present time
    // func getFrameStatistics()

    var timeline: (Semaphore, imageAvailable: UInt64, renderFinished: UInt64)? { get }

    var frameLatency: Int { get }
}

public protocol SurfaceImageProtocol {
    var image: Image { get }
    var view: ImageView { get }

    /// viewport size (might be smaller than actual size)
    var width: UInt32 { get }
    var height: UInt32 { get }

    /// dont start processing command in queue until this are signaled (use when doing queue.submit())
    /// DXGI: nil -> cpu blocking
    var acquireWait: Semaphore? { get }

    /// signal this once we are done
    /// vulkan wsi wait on this
    /// DXGI: nil, will do timeline semaphore
    var renderFinishedSignal: Semaphore? { get }

    /// DXGI: nil, will do timeline semaphore
    var inFlightFence: Fence? { get }

    /// pls transition to this
    var finalLayout: ImageLayout { get }

    /// shouldnt block
    func present() throws
}

class VulkanWSISurface: Surface2 {

    let handle: SurfaceKHR
    var device: DeviceContext!
    let releaseQueue: ReleaseQueue = ReleaseQueue()

    var info: ConfiguredInfo?
    var currentFrameInFlight = 0

    var frameLatency: Int {
        info?.config.frameInFlight ?? 3
    }
    
    let timeline: (Vulkan.Semaphore, imageAvailable: UInt64, renderFinished: UInt64)? = nil

    struct ConfiguredInfo {
        var config: SurfaceConfiguration2
        var availableWidth: UInt32
        var availableHeight: UInt32

        var swapchain: SwapchainKHR
        var images: [Image]
        var imageViews: [ImageView]
        // Per swapchain image (total texture we have)
        var renderFinishedSemaphores: [Semaphore]

        // Per fif
        // we wait this cpu side, to prevent over submission
        var inFlightFences: [Fence]

        // wait this gpu side before starting any work
        var presentCompletedSemaphore: [Semaphore]
    }

    init(_ handle: SurfaceKHR) {
        self.handle = handle
    }

    func associate(device: DeviceContext) {
        self.device = device
    }

    func wait() {
        guard let info else {
            fatalError("Please call .configure first")
        }

        let fence = info.inFlightFences[currentFrameInFlight]
        try! device.device.waitForFences(
            fences: [fence],
            waitAll: true,
            timeout: UInt64.max)

        try! device.device.resetFences(fences: [fence])
    }

    func acquire() throws(SurfaceAcquireError) -> VulkanWSISurfaceImage {
        guard let info else {
            fatalError("Please call .configure first")
        }

        guard
            let index = try? device.device.acquireNextImage2KHR(
                .init(
                    swapchain: info.swapchain,
                    timeout: UInt64.max,
                    // the one we gonna signal once current fif is presented
                    semaphore: info.presentCompletedSemaphore[currentFrameInFlight],
                    deviceMask: 1
                )
            )
        else {
            throw .outOfDate
        }

        currentFrameInFlight = (currentFrameInFlight + 1) / info.config.frameInFlight

        return VulkanWSISurfaceImage(
            image: info.images[Int(index)],
            view: info.imageViews[Int(index)],
            width: info.config.width,
            height: info.config.height,
            acquireWait: info.presentCompletedSemaphore[currentFrameInFlight],
            renderFinishedSignal: info.renderFinishedSemaphores[Int(index)],
            inFlightFence: info.inFlightFences[currentFrameInFlight],
            index: index,
            releaseQueue: self.releaseQueue,
            queue: device.graphicsQueue,
            swapchain: info.swapchain
        )
    }

    func configure(_ configuration: SurfaceConfiguration2) {
        if let c = self.info,
            c.config.onlySizeChanged(comparedTo: configuration),
            c.availableWidth >= configuration.width,
            c.availableHeight >= configuration.height
        {
            let prevSize = (c.config.width, c.config.height)
            let currentSize = (configuration.width, configuration.height)
            self.info!.config = configuration
            Log.verbose(.general, "Reusing... swapchain \(prevSize) -> \(currentSize)")
            return
        }

        let caps = try! device.physicalDevice.getSurfaceCapabilitiesKHR(
            surface: handle)

        let size = SIMD2(Float(configuration.width), Float(configuration.height)) * 1.2
        let clamped = Extent2D(width: UInt32(size.x), height: UInt32(size.y))
            .clamped(from: caps.minImageExtent, to: caps.maxImageExtent)
        let width = clamped.width
        let height = clamped.height

        Log.info(
            .general,
            "Recreating swapchain \((configuration.width, configuration.height)) at real size: \(clamped)"
        )

        nonisolated(unsafe) let prev = info?.swapchain
        let previousSwapchainImageViews = info?.imageViews
        let previousSemaphores = info?.renderFinishedSemaphores  // tf i do with this

        let clock = ContinuousClock()
        let start = clock.now

        var targetImageCount = caps.minImageCount + 1
        if caps.maxImageCount != 0 {
            targetImageCount = max(targetImageCount, caps.maxImageCount)
        }

        let swapchain = try! device.device.createSwapchainKHR(
            .init(
                surface: self.handle,
                minImageCount: targetImageCount,
                imageFormat: configuration.imageFormat,
                imageColorSpace: configuration.colorSpace,
                imageExtent: clamped,
                imageArrayLayers: 1,
                imageUsage: [.colorAttachment, .transferDst],
                imageSharingMode: .exclusive,
                preTransform: caps.currentTransform,
                compositeAlpha: {
                    #if os(Linux)  // wayland
                        .preMultiplied
                    #else
                        .opaque
                    #endif
                }(),
                presentMode: configuration.presentMode == .mailbox ? .mailbox : .fifo,
                clipped: true,
                oldSwapchain: info?.swapchain
            )
        )
        let swapchainImages = try! swapchain.getImagesKHR()
        let swapchainImageViews = swapchainImages.map { image in
            try! device.device.createImageView(
                .init(
                    image: image, viewType: .type2d, format: configuration.imageFormat,
                    components: .init(r: .r, g: .g, b: .b, a: .a),
                    subresourceRange: .init(
                        aspectMask: .color, baseMipLevel: 0, levelCount: 1,
                        baseArrayLayer: 0, layerCount: 1
                    )
                )
            )
        }

        let time = (clock.now - start) / .milliseconds(1)
        Log.info(.compositor, "recreated swapchain in \(time)ms")

        var renderFinishedSemaphores: [Semaphore] = []
        for _ in 0..<swapchainImages.count {
            renderFinishedSemaphores.append(
                try! device.device.createSemaphore()
            )
        }

        var presentCompletedSemaphore: [Semaphore] = []
        var inFlightFences: [Fence] = []
        for _ in 0..<configuration.frameInFlight {
            try! presentCompletedSemaphore.append(device.device.createSemaphore())
            try! inFlightFences.append(device.device.createFence(FenceCreateInfo(flags: .signaled)))
        }

        // everytime present is called
        self.releaseQueue.schedule(in: (info?.config.frameInFlight ?? 0) + 1) {
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

        self.info = ConfiguredInfo(
            config: configuration,
            availableWidth: width,
            availableHeight: height,
            swapchain: swapchain,
            images: swapchainImages,
            imageViews: swapchainImageViews,
            renderFinishedSemaphores: renderFinishedSemaphores,
            inFlightFences: inFlightFences,
            presentCompletedSemaphore: presentCompletedSemaphore
        )
    }
}

struct VulkanWSISurfaceImage: SurfaceImageProtocol {
    let image: Vulkan.Image
    let view: Vulkan.ImageView
    let width: UInt32
    let height: UInt32
    let acquireWait: Vulkan.Semaphore?
    let renderFinishedSignal: Vulkan.Semaphore?
    var inFlightFence: Fence?

    let finalLayout: Vulkan.ImageLayout = .presentSrcKHR

    // implementation private
    let index: UInt32
    let releaseQueue: ReleaseQueue
    let queue: Queue
    let swapchain: SwapchainKHR

    func present() throws {
        self.releaseQueue.flush()
        // do {
        try queue.presentKHR(
            .init(
                waitSemaphores: renderFinishedSignal.map { [$0] } ?? [],
                swapchains: [swapchain],
                imageIndices: [index],
            )
        )
        // } catch {
        //     Log.error(.vulkan, "WSI present error: \(error)")
        // }
    }
}
