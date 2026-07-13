// #if os(Windows)

//     import CPlatform
//     import Foundation
//     import Vulkan
//     import WinSDK

//     /// Presentation through a D3D12 composition swapchain.
//     ///
//     /// D3D12 owns the swapchain and a ring of shared textures; Vulkan imports those
//     /// textures and renders straight into them. Both sides sync on a single shared
//     /// D3D12 fence, imported here as a timeline semaphore. For frame `n`:
//     ///
//     ///   2n + 1  vulkan is done rendering into image `n % imageCount`
//     ///   2n + 2  d3d12 is done copying that image into the backbuffer
//     ///
//     /// so a frame may only start once the frame `imageCount` before it has reached
//     /// its copy-done value.
//     class SlopDXGISurface: Surface2 {
//         typealias SurfaceImage = SlopDXGISurfaceImage

//         /// the d3d12 shared texture is created as B8G8R8A8_UNORM_SRGB
//         static let format: Format = .b8g8r8a8Srgb
//         /// as many as `D3D12Images` can carry
//         static let maxImageCount = 3

//         var device: DeviceContext!
//         let releaseQueue: ReleaseQueue = ReleaseQueue()

//         var info: ConfiguredInfo?
//         struct ConfiguredInfo {
//             var config: SurfaceConfiguration2
//             var imageCount: Int

//             var images: [Image]
//             var imageViews: [ImageView]
//             var memories: [DeviceMemory]

//             /// imported from the d3d12 fence, timeline
//             var importedSemaphore: Semaphore
//         }

//         /// how many frames were handed out, also drives the timeline values
//         private var frameCount: UInt64 = 0

//         var frameLatency: Int {
//             info?.imageCount ?? 2
//         }

//         var presenter: UnsafeMutableRawPointer!
//         let hwnd: HWND

//         init(hwnd: HWND) {
//             self.hwnd = hwnd
//         }

//         func associate(device: DeviceContext) {
//             self.device = device
//         }

//         private func renderDoneValue(frame: UInt64) -> UInt64 { frame * 2 + 1 }
//         private func copyDoneValue(frame: UInt64) -> UInt64 { frame * 2 + 2 }

//         /// the highest value d3d12 will ever reach for the frames queued so far
//         private var lastQueuedValue: UInt64 {
//             frameCount == 0 ? 0 : copyDoneValue(frame: frameCount - 1)
//         }

//         func wait() {
//             guard let info else {
//                 fatalError("Please call .configure first")
//             }

//             // pace against the swapchain: blocks while more than
//             // `maximum frame latency` frames are queued
//             d3d12_presenter_wait(presenter)

//             // the image we are about to hand out still belongs to d3d12 until it has
//             // copied the frame that last used it. SurfaceImage.acquireWait is nil, so
//             // this cpu block is what keeps that ordering.
//             let imageCount = UInt64(info.imageCount)
//             guard frameCount >= imageCount else { return }

//             do {
//                 try device.device.waitSemaphores(
//                     SemaphoreWaitInfo(
//                         semaphores: [info.importedSemaphore],
//                         values: [copyDoneValue(frame: frameCount - imageCount)]
//                     ),
//                     timeout: UInt64.max
//                 )
//             } catch {
//                 Log.error(.vulkan, "DXGISurface.wait: \(error)")
//             }
//         }

//         func acquire() throws(SurfaceAcquireError) -> SlopDXGISurfaceImage {
//             guard let info else {
//                 fatalError("Please call .configure first")
//             }

//             let frame = frameCount
//             let index = Int(frame % UInt64(info.imageCount))
//             frameCount += 1

//             return SlopDXGISurfaceImage(
//                 image: info.images[index],
//                 view: info.imageViews[index],
//                 width: info.config.width,
//                 height: info.config.height,
//                 index: UInt32(index),
//                 renderDoneValue: renderDoneValue(frame: frame),
//                 copyDoneValue: copyDoneValue(frame: frame),
//                 timeline: info.importedSemaphore,
//                 queue: device.graphicsQueue,
//                 presenter: presenter,
//                 releaseQueue: releaseQueue
//             )
//         }

//         func configure(_ configuration: SurfaceConfiguration2) {
//             if configuration.imageFormat != Self.format {
//                 Log.warn(
//                     .general,
//                     "DXGISurface only presents \(Self.format), ignoring \(configuration.imageFormat)"
//                 )
//             }

//             let imageCount = min(max(configuration.frameInFlight, 1), Self.maxImageCount)

//             guard let current = info else {
//                 create(configuration, imageCount: imageCount)
//                 return
//             }

//             // the ring size changed, there is nothing left to reuse
//             if current.imageCount != imageCount {
//                 destroy()
//                 create(configuration, imageCount: imageCount)
//                 return
//             }

//             // d3d12 copies the shared texture into the backbuffer whole, so the two
//             // must agree on the exact size: no slack to grow into, every size change
//             // is a real resize.
//             guard
//                 current.config.width != configuration.width
//                     || current.config.height != configuration.height
//             else {
//                 info!.config = configuration
//                 return
//             }

//             resize(configuration)
//         }

//         private func create(_ configuration: SurfaceConfiguration2, imageCount: Int) {
//             presenter = d3d12_presenter_new(
//                 configuration.width, configuration.height, hwnd, UInt32(imageCount))
//             // fresh presenter, fresh fence, so the timeline restarts at 0
//             frameCount = 0

//             let semaphore = try! device.device.createSemaphore(
//                 SemaphoreCreateInfo()
//                     .push(SemaphoreTypeCreateInfo(semaphoreType: .timeline, initialValue: 0))
//             )

//             try! device.device.importSemaphoreWin32HandleKHR(
//                 ImportSemaphoreWin32HandleInfoKHR(
//                     semaphore: semaphore,
//                     handleType: .d3d12Fence,
//                     handle: d3d12_presenter_get_fence(presenter)
//                 )
//             )

//             let (images, imageViews, memories) = importImages(
//                 width: configuration.width, height: configuration.height)

//             self.info = ConfiguredInfo(
//                 config: configuration,
//                 imageCount: imageCount,
//                 images: images,
//                 imageViews: imageViews,
//                 memories: memories,
//                 importedSemaphore: semaphore
//             )
//         }

//         private func resize(_ configuration: SurfaceConfiguration2) {
//             guard let current = info else { return }

//             let prevSize = (current.config.width, current.config.height)
//             let size = (configuration.width, configuration.height)
//             Log.info(.general, "Resizing d3d12 swapchain \(prevSize) -> \(size)")

//             try! device.device.waitIdle()

//             // waits for the last copy to retire, then drops the old shared textures and
//             // makes new ones. the fence itself survives, so the timeline keeps running.
//             _ = d3d12_presenter_resize(
//                 presenter, configuration.width, configuration.height, lastQueuedValue)

//             destroyImages(current)

//             let (images, imageViews, memories) = importImages(
//                 width: configuration.width, height: configuration.height)

//             info!.config = configuration
//             info!.images = images
//             info!.imageViews = imageViews
//             info!.memories = memories
//         }

//         private func destroy() {
//             guard let current = info else { return }

//             try! device.device.waitIdle()
//             destroyImages(current)
//             current.importedSemaphore.destroy()
//             d3d12_presenter_destroy(presenter, lastQueuedValue)

//             presenter = nil
//             info = nil
//             frameCount = 0
//         }

//         private func destroyImages(_ info: ConfiguredInfo) {
//             for view in info.imageViews {
//                 view.destroy()
//             }
//             for image in info.images {
//                 image.destroy()
//             }
//             for memory in info.memories {
//                 memory.freeMemory()
//             }
//         }

//         /// wrap every shared texture of the presenter in a VkImage backed by the
//         /// d3d12 resource it was exported from
//         private func importImages(width: UInt32, height: UInt32) -> (
//             [Image], [ImageView], [DeviceMemory]
//         ) {
//             let d3d12Images = d3d12_presenter_get_images(presenter)
//             let handles = [d3d12Images.image1, d3d12Images.image2, d3d12Images.image3]
//                 .prefix(Int(d3d12Images.image_count))

//             var images: [Image] = []
//             var imageViews: [ImageView] = []
//             var memories: [DeviceMemory] = []

//             for handle in handles {
//                 let image = try! device.device.createImage(
//                     ImageCreateInfo(
//                         imageType: .type2d,
//                         format: Self.format,
//                         extent: Extent3D(width: width, height: height, depth: 1),
//                         mipLevels: 1,
//                         arrayLayers: 1,
//                         samples: .type1,
//                         tiling: .optimal,
//                         usage: [.colorAttachment, .transferDst, .transferSrc],
//                         sharingMode: .exclusive,
//                         initialLayout: .undefined
//                     )
//                     .push(ExternalMemoryImageCreateInfo(handleTypes: .d3d12Resource))
//                 )

//                 let requirements = image.getMemoryRequirements()
//                 let handleProperties = try! device.device.getMemoryWin32HandlePropertiesKHR(
//                     handleType: .d3d12Resource, handle: handle)

//                 guard
//                     let memoryTypeIndex = memoryTypeIndex(
//                         for: requirements.memoryTypeBits & handleProperties.memoryTypeBits)
//                 else {
//                     fatalError("DXGISurface: no memory type can back the imported d3d12 texture")
//                 }

//                 // d3d12 resources are always their own allocation
//                 let memory = try! device.device.allocateMemory(
//                     MemoryAllocateInfo(
//                         allocationSize: requirements.size,
//                         memoryTypeIndex: memoryTypeIndex
//                     )
//                     .push(MemoryDedicatedAllocateInfo(image: image))
//                     .push(
//                         ImportMemoryWin32HandleInfoKHR(
//                             handleType: .d3d12Resource,
//                             handle: handle
//                         )
//                     )
//                 )
//                 try! image.bindMemory(memory: memory, memoryOffset: 0)

//                 let view = try! device.device.createImageView(
//                     ImageViewCreateInfo(
//                         image: image,
//                         viewType: .type2d,
//                         format: Self.format,
//                         components: .init(r: .r, g: .g, b: .b, a: .a),
//                         subresourceRange: .init(
//                             aspectMask: .color, baseMipLevel: 0, levelCount: 1,
//                             baseArrayLayer: 0, layerCount: 1
//                         )
//                     )
//                 )

//                 images.append(image)
//                 imageViews.append(view)
//                 memories.append(memory)
//             }

//             return (images, imageViews, memories)
//         }

//         private func memoryTypeIndex(for typeBits: UInt32) -> UInt32? {
//             let properties = device.physicalDevice.getMemoryProperties()
//             for index in 0..<Int(properties.memoryTypeCount)
//             where typeBits & (1 << UInt32(index)) != 0
//                 && properties.memoryTypes[index].propertyFlags.contains(.deviceLocal)
//             {
//                 return UInt32(index)
//             }
//             return nil
//         }
//     }

//     struct SlopDXGISurfaceImage: SurfaceImageProtocol {
//         var image: Image
//         var view: ImageView

//         /// viewport size (might be smaller than actual size)
//         var width: UInt32
//         var height: UInt32

//         /// DXGI: nil -> cpu blocking, see DXGISurface.wait
//         var acquireWait: Semaphore? { nil }
//         /// DXGI: nil -> will do timeline semaphore
//         var renderFinishedSignal: Semaphore? { nil }
//         var inFlightFence: Fence? { nil }
//         /// d3d12 copies it out of here, and knows nothing about vulkan layouts
//         var finalLayout: ImageLayout { .general }

//         // implementation private
//         let index: UInt32
//         let renderDoneValue: UInt64
//         let copyDoneValue: UInt64
//         let timeline: Semaphore
//         let queue: Queue
//         let presenter: UnsafeMutableRawPointer
//         let releaseQueue: ReleaseQueue

//         func present() throws {
//             releaseQueue.flush()

//             // the render submit carried no signal semaphore (renderFinishedSignal is
//             // nil), so tack the timeline signal on here: it runs after that submit
//             // because they share a queue.
//             try queue.submit2(submits: [
//                 SubmitInfo2(
//                     signalSemaphoreInfos: [
//                         SemaphoreSubmitInfo(
//                             semaphore: timeline,
//                             value: renderDoneValue,
//                             stageMask: .allCommands,
//                             deviceIndex: 0
//                         )
//                     ]
//                 )
//             ])

//             // d3d12 queue-waits for renderDoneValue, copies, presents, then signals
//             // copyDoneValue. nothing blocks here.
//             _ = d3d12_presenter_present(presenter, index, renderDoneValue, copyDoneValue)
//         }
//     }

// #endif
