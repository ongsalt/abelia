import CSTBImage
import CShim
import Vulkan

class VmaImage {
    let image: Image
    let view: ImageView
    private let allocation: VmaAllocation
    private let allocator: VmaAllocator
    let size: SIMD2<UInt32>

    init(
        _ image: Image, _ view: ImageView,
        _ allocation: VmaAllocation, _ allocator: VmaAllocator,
        size: SIMD2<UInt32>
    ) {
        self.image = image
        self.view = view
        self.allocation = allocation
        self.allocator = allocator
        self.size = size
    }

    func destroy() {
        view.destroy()
        vmaDestroyImage(allocator, image.handle, allocation)
    }
}

/// Temporary resources from an in-flight image upload.
/// Add `uploadSemaphore` to the next render submit's `waitSemaphoreInfos`,
/// then call `cleanup(device:)` once that submit has completed.
struct ImageUploadTicket {
    let uploadSemaphore: Semaphore
    let fence: Fence
    let staging: VmaBuffer
    let commandPool: CommandPool

    func cleanup(device: Device) throws(Vulkan.Result) {
        // TODO: integrate this with
        try device.waitForFences(fences: [fence], waitAll: true, timeout: .max)
        staging.destroy()
    }
}

// TODO: proper resource loading queue
extension DeviceContext {
    /// Decode an image from `fd` and begin uploading it to the GPU immediately.
    /// - Returns: The GPU image and a ticket for synchronizing / cleaning up the upload.
    func loadImage(filename: String) throws(Vulkan.Result) -> (
        image: VmaImage, ticket: ImageUploadTicket
    ) {
        // --- Decode ---
        var w: Int32 = 0
        var h: Int32 = 0
        var ch: Int32 = 0
        guard let pixels = stbi_load(filename, &w, &h, &ch, 4) else {
            fatalError("stbi_load_from_fd: failed to decode image")
        }
        defer { stbi_image_free(pixels) }
        let width = UInt32(w)
        let height = UInt32(h)
        let byteCount = Int(width) * Int(height) * 4

        // --- Staging buffer (host-visible, pre-mapped) ---
        let staging = try createVmaBuffer(size: UInt64(byteCount), usages: .transferSrc)
        staging.bufferPointer!.baseAddress!.copyMemory(from: pixels, byteCount: byteCount)
        vmaFlushAllocation(allocator, staging.allocation, 0, UInt64(byteCount))

        // --- GPU-local image ---
        var vkImage: VkImage?
        var vmaAlloc: VmaAllocation?
        var vmaCi = VmaAllocationCreateInfo()
        vmaCi.usage = VMA_MEMORY_USAGE_AUTO
        let extent = Extent3D(width: width, height: height, depth: 1)
        try checkResult(
            ImageCreateInfo(
                imageType: .type2d,
                format: .r8g8b8a8Srgb,
                extent: extent,
                mipLevels: 1,
                arrayLayers: 1,
                samples: .type1,
                tiling: .optimal,
                usage: [.transferDst, .sampled],
                sharingMode: .exclusive,
                initialLayout: .undefined
            ).withCStruct { vmaCreateImage(allocator, $0, &vmaCi, &vkImage, &vmaAlloc, nil) }
        )

        let image = Image(handle: vkImage!, device: device)
        let view = try device.createImageView(
            .init(
                image: image,
                viewType: .type2d,
                format: .r8g8b8a8Srgb,
                components: .init(r: .r, g: .g, b: .b, a: .a),
                subresourceRange: .init(
                    aspectMask: .color, baseMipLevel: 0, levelCount: 1,
                    baseArrayLayer: 0, layerCount: 1)
            ))

        // --- One-time upload command buffer ---
        let pool = try device.createCommandPool(
            .init(flags: .transient, queueFamilyIndex: graphicsFamilyIndex))
        let cmd = try device.allocateCommandBuffers(
            .init(commandPool: pool, level: .primary, commandBufferCount: 1))[0]
        try cmd.begin(.init(flags: .oneTimeSubmit))

        let sub = ImageSubresourceRange(
            aspectMask: .color, baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0, layerCount: 1)
        let qf = graphicsFamilyIndex

        // UNDEFINED → TRANSFER_DST_OPTIMAL
        cmd.pipelineBarrier2(
            .init(imageMemoryBarriers: [
                ImageMemoryBarrier2(
                    srcStageMask: .none, srcAccessMask: [],
                    dstStageMask: .copy, dstAccessMask: .transferWrite,
                    oldLayout: .undefined, newLayout: .transferDstOptimal,
                    srcQueueFamilyIndex: qf, dstQueueFamilyIndex: qf,
                    image: image, subresourceRange: sub)
            ]))

        // Buffer → Image
        cmd.copyBufferToImage(
            srcBuffer: staging.buffer,
            dstImage: image,
            dstImageLayout: .transferDstOptimal,
            regions: [
                BufferImageCopy(
                    bufferOffset: 0, bufferRowLength: 0, bufferImageHeight: 0,
                    imageSubresource: ImageSubresourceLayers(
                        aspectMask: .color, mipLevel: 0, baseArrayLayer: 0, layerCount: 1),
                    imageOffset: Offset3D(x: 0, y: 0, z: 0),
                    imageExtent: extent)
            ]
        )

        // TRANSFER_DST_OPTIMAL → SHADER_READ_ONLY_OPTIMAL
        cmd.pipelineBarrier2(
            .init(imageMemoryBarriers: [
                ImageMemoryBarrier2(
                    srcStageMask: .copy, srcAccessMask: .transferWrite,
                    dstStageMask: .fragmentShader, dstAccessMask: .shaderSampledRead,
                    oldLayout: .transferDstOptimal, newLayout: .shaderReadOnlyOptimal,
                    srcQueueFamilyIndex: qf, dstQueueFamilyIndex: qf,
                    image: image, subresourceRange: sub)
            ]))

        try cmd.end()

        // --- Submit immediately ---
        let uploadSemaphore = try device.createSemaphore()
        let fence = try device.createFence(.init())
        try graphicsQueue.submit2(
            submits: [
                SubmitInfo2(
                    waitSemaphoreInfos: [],
                    commandBufferInfos: [.init(commandBuffer: cmd, deviceMask: 0)],
                    signalSemaphoreInfos: [
                        .init(
                            semaphore: uploadSemaphore, value: 0, stageMask: .allTransfer,
                            deviceIndex: 0)
                    ]
                )
            ],
            fence: fence)

        return (
            VmaImage(image, view, vmaAlloc!, allocator, size: SIMD2(width, height)),
            ImageUploadTicket(
                uploadSemaphore: uploadSemaphore,
                fence: fence,
                staging: staging,
                commandPool: pool)
        )
    }
}
