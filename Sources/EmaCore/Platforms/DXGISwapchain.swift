import CEmaPlatforms
@preconcurrency import CVulkan
import Pointer

class DXGISwapchain: @unchecked Sendable, SwapchainProtocol {
    typealias SwapchainImage = DXGISwapchainImage

    var size: SIMD2<UInt32> { imageSize }

    private let device: GraphicsDevice
    private let hwnd: HWND
    private let interopHandle: UnsafeMutableRawPointer

    private var images: [VkImage] = []
    private var imageViews: [VkImageView] = []
    private var vmaAllocations: [VmaAllocation] = []
    private var sharedHandles: [HANDLE?] = []

    private var renderFinishedSemaphore: VkSemaphore?
    private var presentCompletedSemaphore: VkSemaphore?

    private var currentFrameIndex: UInt64 = 1
    static let maxFramesInFlight = 2

    public private(set) var imageFormat: VkFormat = VK_FORMAT_B8G8R8A8_UNORM
    public private(set) var imageSize: SIMD2<UInt32>

    public init(hwnd: HWND, on device: GraphicsDevice, initialSize size: SIMD2<UInt32>) {
        self.device = device
        self.hwnd = hwnd
        self.imageSize = size

        guard let interop = createDirectCompositionInterop(hwnd, Int32(Self.maxFramesInFlight))
        else {
            fatalError("DXGISwapchain initialization fault: Interop failed to instantiate.")
        }
        self.interopHandle = interop

        let fences = DirectCompositionInterop_getFences(interopHandle)

        let timelineTypeCI = Box(VkSemaphoreTypeCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO
            $0.semaphoreType = VK_SEMAPHORE_TYPE_TIMELINE
            $0.initialValue = 0
        }

        var renderFinishedCI = with(VkSemaphoreCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            $0.pNext = timelineTypeCI.raw
        }
        vkCreateSemaphore(device.handle, &renderFinishedCI, nil, &self.renderFinishedSemaphore)
            .unwrap()

        let importRenderFinished = Box(VkImportSemaphoreWin32HandleInfoKHR()) {
            $0.sType = VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_WIN32_HANDLE_INFO_KHR
            $0.handleType = VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_BIT_KHR
            $0.handle = fences.renderFinishedFenceHandle
            $0.semaphore = self.renderFinishedSemaphore
        }

        vkImportSemaphoreWin32HandleKHR(device.handle, importRenderFinished.ptr).unwrap()
        self.renderFinishedSemaphore = importRenderFinished.pointee.semaphore


        var copyCompletedCI = with(VkSemaphoreCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            $0.pNext = timelineTypeCI.raw
        }
        vkCreateSemaphore(device.handle, &copyCompletedCI, nil, &self.presentCompletedSemaphore)
            .unwrap()
        let importCopyCompleted = Box(VkImportSemaphoreWin32HandleInfoKHR()) {
            $0.sType = VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_WIN32_HANDLE_INFO_KHR
            $0.handleType = VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_BIT_KHR
            $0.handle = fences.copyCompletedFenceHandle
            $0.semaphore = self.presentCompletedSemaphore
        }

        vkImportSemaphoreWin32HandleKHR(device.handle, importCopyCompleted.ptr).unwrap()
        self.presentCompletedSemaphore = importCopyCompleted.pointee.semaphore


        self.allocateSharedImages(size: size)
    }

    private func allocateSharedImages(size: SIMD2<UInt32>) {
        // GPU Sync: Wait for graphics work to finish before destroying bound resources

        // TODO: schedule image view destroy
        // remove idle image
        // Task { sleep(2 sec) }
        // device.waitIdle()
        // for view in imageViews { vkDestroyImageView(device.handle, view, nil) }
        // for (img, alloc) in zip(images, vmaAllocations) {
        //     vmaDestroyImage(device.vma, img, alloc)
        // }

        images.removeAll()
        imageViews.removeAll()
        vmaAllocations.removeAll()
        sharedHandles.removeAll()

        for _ in 0..<Self.maxFramesInFlight {
            let externalImageCI = Box(VkExternalMemoryImageCreateInfo()) {
                $0.sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO
                $0.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT_KHR.u32
            }

            let imageCI = Box(VkImageCreateInfo()) {
                $0.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
                $0.pNext = externalImageCI.raw
                $0.imageType = VK_IMAGE_TYPE_2D
                $0.format = VK_FORMAT_B8G8R8A8_UNORM
                $0.extent = .init(width: size.x, height: size.y, depth: 1)
                $0.mipLevels = 1
                $0.arrayLayers = 1
                $0.samples = VK_SAMPLE_COUNT_1_BIT
                $0.tiling = VK_IMAGE_TILING_OPTIMAL
                $0.usage =
                    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.u32 | VK_IMAGE_USAGE_TRANSFER_SRC_BIT.u32
                $0.sharingMode = VK_SHARING_MODE_EXCLUSIVE
            }

            // Cross-adapter/shared images require dedicated memory allocations
            let allocationCI = Box(VmaAllocationCreateInfo()) {
                $0.flags = VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT.u32
                $0.usage = VMA_MEMORY_USAGE_AUTO
            }

            var img: VkImage?
            var alloc: VmaAllocation?
            var allocInfo = VmaAllocationInfo()
            vmaCreateImage(
                device.vma, imageCI.ptr, allocationCI.ptr, &img, &alloc, &allocInfo
            ).unwrap()

            images.append(img!)
            vmaAllocations.append(alloc!)

            let getHandleInfo = Box(VkMemoryGetWin32HandleInfoKHR()) {
                $0.sType = VK_STRUCTURE_TYPE_MEMORY_GET_WIN32_HANDLE_INFO_KHR
                $0.memory = allocInfo.deviceMemory
                $0.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT_KHR
            }

            var handle: HANDLE?
            vkGetMemoryWin32HandleKHR(device.handle, getHandleInfo.ptr, &handle).unwrap()
            sharedHandles.append(handle)

            let view = createImageView(
                device: device.handle, image: img!, format: VK_FORMAT_B8G8R8A8_UNORM)
            imageViews.append(view)
        }

        var mutableHandles = sharedHandles
        mutableHandles.withUnsafeMutableBufferPointer { buffer in
            let ptr = OpaquePointer(buffer.baseAddress)
            DirectCompositionInterop_resize(
                interopHandle, Int32(Self.maxFramesInFlight), UnsafeMutablePointer(ptr))
        }
    }

    func waitForNextImage() {
        DirectCompositionInterop_waitForImage(interopHandle, Int32(currentFrameIndex))
    }

    public func acquireNextImage(commandBuffer: VkCommandBuffer) -> DXGISwapchainImage {
        let imageIdx = Int(currentFrameIndex % UInt64(Self.maxFramesInFlight))

        let image = DXGISwapchainImage(
            commandBuffer: commandBuffer,
            image: images[imageIdx],
            imageView: imageViews[imageIdx],
            timelineValue: currentFrameIndex,
            presentCompletedSemaphore: presentCompletedSemaphore!,
            renderFinishedSemaphore: renderFinishedSemaphore!,
            swapchain: self,
        )

        image.prepareRendering()

        return image
    }

    fileprivate func present(frameIndex: UInt64) {
        DirectCompositionInterop_present(interopHandle, Int32(frameIndex))
        currentFrameIndex += 1
    }

    public func recreate() {
        self.allocateSharedImages(size: self.imageSize)
    }

    public func destroy() {
        device.waitIdle()

        for view in imageViews { vkDestroyImageView(device.handle, view, nil) }
        for (img, alloc) in zip(images, vmaAllocations) {
            vmaDestroyImage(device.vma, img, alloc)
        }

        vkDestroySemaphore(device.handle, renderFinishedSemaphore, nil)
        vkDestroySemaphore(device.handle, presentCompletedSemaphore, nil)
        DirectCompositionInterop_destroy(interopHandle)

        images.removeAll()
        imageViews.removeAll()
        vmaAllocations.removeAll()
    }
}

struct DXGISwapchainImage: @unchecked Sendable, SwapchainImageProtocol {
    let commandBuffer: VkCommandBuffer
    let image: VkImage
    let imageView: VkImageView
    let timelineValue: UInt64?

    let presentCompletedSemaphore: VkSemaphore
    let renderFinishedSemaphore: VkSemaphore

    var inFlightFence: VkFence? { nil }
    let swapchain: DXGISwapchain

    fileprivate func prepareRendering() {
        let image = self.image
        let barrier = Box(VkImageMemoryBarrier2()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
            $0.image = image
            $0.subresourceRange = .init(
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.u32,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1
            )
            $0.srcStageMask = VK_PIPELINE_STAGE_2_NONE
            $0.srcAccessMask = VK_ACCESS_2_NONE
            $0.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED

            $0.dstStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
            $0.dstAccessMask = VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT
            $0.newLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
        }

        var dependencyInfo = with(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
            $0.pImageMemoryBarriers = barrier.ptr
        }
        vkCmdPipelineBarrier2(commandBuffer, &dependencyInfo)
    }

    func transitionToPresentable() {
        let image = self.image
        let barrier = Box(VkImageMemoryBarrier2()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
            $0.image = image
            $0.subresourceRange = .init(
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.u32,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1
            )
            $0.srcStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
            $0.srcAccessMask = VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT
            $0.oldLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL

            $0.dstStageMask = VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT
            $0.dstAccessMask = VK_ACCESS_2_TRANSFER_READ_BIT
            $0.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
        }

        var dependencyInfo = with(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
            $0.pImageMemoryBarriers = barrier.ptr
        }
        vkCmdPipelineBarrier2(commandBuffer, &dependencyInfo)
    }

    consuming func present() {
        swapchain.present(frameIndex: timelineValue!)
    }
}
