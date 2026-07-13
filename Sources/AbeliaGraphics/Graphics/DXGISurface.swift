#if os(Windows)

    import Foundation
    import CPlatform
    import WinSDK
    import Vulkan

    /// Vulkan do some shit and write into Image 1 (from presenter) = n
    /// presenter wait until vulkan is done writing (n), then blit into swapchain image
    /// then tell everyone that that image is available for writing again (n+1)
    /// vulkan wait for n + 1 (in queue.submit()) and so on, but actually we have >1 frame latency
    class DXGISurface: Surface2 {

        typealias SurfaceImage = DXGISurfaceImage

        var device: DeviceContext!
        let releaseQueue: ReleaseQueue = ReleaseQueue()

        var info: ConfiguredInfo?
        struct ConfiguredInfo {
            var config: SurfaceConfiguration2
            var availableWidth: UInt32
            var availableHeight: UInt32

            var semaphore: Semaphore
            var images: [Image]
            var imageViews: [ImageView]
            var memories: [DeviceMemory]
        }

        var frameLatency: Int {
            // pre-configure fallback matches SurfaceConfiguration2's default
            info?.config.frameInFlight ?? 2
        }

        var timeline: (Semaphore, imageAvailable: UInt64, renderFinished: UInt64)? {
            let latency = UInt64(frameLatency)
            let imageAvailable = frameIndex > latency ? (frameIndex - latency) * 2 : 0
            return (info!.semaphore, imageAvailable, frameIndex * 2 - 1)
        }

        var presenter: UnsafeMutableRawPointer!
        let hwnd: HWND

        var frameIndex: UInt64 = 0

        static let format: Format = .b8g8r8a8Srgb

        init(hwnd: HWND) {
            self.hwnd = hwnd
        }

        func associate(device: DeviceContext) {
            self.device = device
        }

        func wait() {
            // vulkan: render [1] finished -> signal 1
            // dxgi: wait for 1, copy [1] into swapchain -> signal 2 (done with the image)
            // vulkan: render [2] finished -> signal 3
            // dxgi: wait for 3, copy [2] into swapchain -> signal 4

            // vulkan: wait for 2, render [1] finished -> signal 5
            // dxgi...
            // vulkan: wait for 4, render [2] finished -> signal 7
            // dxgi...

            // wait until dxgi want us to
            d3d12_presenter_wait(presenter)

            if frameIndex > frameLatency {
                // care only render finished
                let v = (frameIndex - UInt64(frameLatency)) * 2
                // d3d12_presenter_wait_value(presenter, v)
                // we can actually use vulkan wait tho...
                try! device.device.waitSemaphores(
                    SemaphoreWaitInfo(semaphores: [info!.semaphore], values: [v]),
                    timeout: UInt64.max
                )
            }
        }

        func acquire() throws(SurfaceAcquireError) -> SurfaceImage {
            // fatalError("DXGISurface::acquire is not implemented")
            guard let info else {
                fatalError("pls call .configure first")
            }
            frameIndex += 1
            let waitRenderFinished = frameIndex * 2 - 1
            let signalImageAvailable = frameIndex * 2

            let index = UInt32(frameIndex) % UInt32(frameLatency)

            return DXGISurfaceImage(
                image: info.images[Int(index)],
                view: info.imageViews[Int(index)],
                width: info.config.width,
                height: info.config.height,
                releaseQueue: releaseQueue,
                presenter: presenter,
                index: index,
                waitRenderFinished: waitRenderFinished,
                signalImageAvailable: signalImageAvailable,
            )
        }

        // TODO: resize path
        func configure(_ configuration: SurfaceConfiguration2) {
            guard let info else {
                create(configuration)
                return
            }

            if info.config == configuration {
                return
            }

            // if we can just crop
            if info.config.onlySizeChanged(comparedTo: configuration)
                && info.availableWidth >= configuration.width
                && info.availableHeight >= configuration.height
            {
                // Log.verbose(
                //     .general,
                //     "reusing dxgi swapchain \((configuration.width, configuration.height)) at real size: \((info.availableWidth, info.availableHeight))"
                // )
                self.info!.config = configuration
                return
            }

            let width = UInt32(Float(configuration.width) * 1.2)
            let height = UInt32(Float(configuration.height) * 1.2)

            Log.info(
                .general,
                "Resizing dxgi swapchain \((configuration.width, configuration.height)) at real size: \((width, height))"
            )

            d3d12_presenter_resize(presenter, width, height, frameIndex * 2)

            // safe to release previos images/views cuz d3d12_presenter_resize already waitIdle
            let prevViews = info.imageViews
            let prevImages = info.images
            let prevMemories = info.memories
            releaseQueue.schedule(in: info.config.frameInFlight + 1) {
                for view in prevViews {
                    view.destroy()
                }
                for image in prevImages {
                    image.destroy()
                }
                for memory in prevMemories {
                    memory.freeMemory()
                }
            }

            let d3d12Images = d3d12_presenter_get_images(presenter)
            let (images, views, memories) = importImages(from: d3d12Images)

            self.info = ConfiguredInfo(
                config: configuration,
                availableWidth: d3d12Images.width,
                availableHeight: d3d12Images.height,
                semaphore: info.semaphore,
                images: images,
                imageViews: views,
                memories: memories
            )
        }

        private func create(_ configuration: SurfaceConfiguration2) {
            presenter = d3d12_presenter_new(
                UInt32(Float(configuration.width) * 1.2),
                UInt32(Float(configuration.height) * 1.2),
                hwnd,
                UInt32(configuration.frameInFlight)
            )

            let semaphore = try! device.device.createSemaphore(
                SemaphoreCreateInfo()
                    .push(SemaphoreTypeCreateInfo(semaphoreType: .timeline, initialValue: 0))
            )
            try! device.device.importSemaphoreWin32HandleKHR(
                ImportSemaphoreWin32HandleInfoKHR(
                    semaphore: semaphore,
                    handleType: .d3d12Fence,
                    handle: d3d12_presenter_get_fence(presenter),
                )
            )

            let d3d12Images = d3d12_presenter_get_images(presenter)
            let (images, views, memories) = importImages(from: d3d12Images)

            // TODO: destroy previous one

            self.info = ConfiguredInfo(
                config: configuration,
                availableWidth: d3d12Images.width,
                availableHeight: d3d12Images.height,
                semaphore: semaphore,
                images: images,
                imageViews: views,
                memories: memories
            )
        }

        private func importImages(from s: D3D12Images) -> (
            [Image], [ImageView], [DeviceMemory]
        ) {
            let handles = [s.image1, s.image2, s.image3]
                .prefix(Int(s.image_count))

            var images: [Image] = []
            var imageViews: [ImageView] = []
            var memories: [DeviceMemory] = []

            for handle in handles {
                let image = try! device.device.createImage(
                    ImageCreateInfo(
                        imageType: .type2d,
                        format: Self.format,
                        extent: Extent3D(
                            width: s.width, height: s.height, depth: 1),
                        mipLevels: 1,
                        arrayLayers: 1,
                        samples: .type1,
                        tiling: .optimal,
                        usage: [.colorAttachment, .transferDst, .transferSrc],
                        sharingMode: .exclusive,
                        initialLayout: .undefined
                    )
                    .push(ExternalMemoryImageCreateInfo(handleTypes: .d3d12Resource))
                )

                let requirements = image.getMemoryRequirements()
                let handleProperties = try! device.device.getMemoryWin32HandlePropertiesKHR(
                    handleType: .d3d12Resource, handle: handle!)

                guard
                    let memoryTypeIndex = memoryTypeIndex(
                        for: requirements.memoryTypeBits & handleProperties.memoryTypeBits)
                else {
                    fatalError("DXGISurface: no memory type can back the imported d3d12 texture")
                }

                // d3d12 resources are always their own allocation
                let memory = try! device.device.allocateMemory(
                    MemoryAllocateInfo(
                        allocationSize: requirements.size,
                        memoryTypeIndex: memoryTypeIndex
                    )
                    .push(MemoryDedicatedAllocateInfo(image: image))
                    .push(
                        ImportMemoryWin32HandleInfoKHR(
                            handleType: .d3d12Resource,
                            handle: handle
                        )
                    )
                )
                try! image.bindMemory(memory: memory, memoryOffset: 0)

                let view = try! device.device.createImageView(
                    ImageViewCreateInfo(
                        image: image,
                        viewType: .type2d,
                        format: Self.format,
                        components: .init(r: .r, g: .g, b: .b, a: .a),
                        subresourceRange: .init(
                            aspectMask: .color, baseMipLevel: 0, levelCount: 1,
                            baseArrayLayer: 0, layerCount: 1
                        )
                    )
                )

                images.append(image)
                imageViews.append(view)
                memories.append(memory)
            }

            return (images, imageViews, memories)
        }

        // TODO: nuke this and use vma
        private func memoryTypeIndex(for typeBits: UInt32) -> UInt32? {
            let properties = device.physicalDevice.getMemoryProperties()
            for index in 0..<Int(properties.memoryTypeCount)
            where typeBits & (1 << UInt32(index)) != 0
                && properties.memoryTypes[index].propertyFlags.contains(.deviceLocal)
            {
                return UInt32(index)
            }
            return nil
        }
    }

    struct DXGISurfaceImage: SurfaceImageProtocol {
        var image: Image
        var view: ImageView

        /// viewport size (might be smaller than actual size)
        var width: UInt32
        var height: UInt32

        /// DXGI: nil -> will do timeline semaphore
        var acquireWait: Semaphore? { nil }
        var renderFinishedSignal: Semaphore? { nil }
        var inFlightFence: Fence? { nil }
        var finalLayout: ImageLayout {
            // bruh is this amd thing
            .transferSrcOptimal
        }

        let releaseQueue: ReleaseQueue
        let presenter: UnsafeMutableRawPointer
        let index: UInt32
        let waitRenderFinished: UInt64
        let signalImageAvailable: UInt64

        func present() throws {
            releaseQueue.flush()
            d3d12_presenter_present(presenter, index, waitRenderFinished, signalImageAvailable)
        }
    }

#endif
