import CSTBImage
import CShim
import Vulkan

extension TextureRegistry {
    public func loadImage(filename: String) throws(Vulkan.Result) -> GPUFuture<RenderTexture> {
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
        let staging = try context.createVmaBuffer(size: UInt64(byteCount), usages: .transferSrc)
        staging.bufferPointer!.baseAddress!.copyMemory(from: pixels, byteCount: byteCount)
        vmaFlushAllocation(context.allocator, staging.allocation, 0, UInt64(byteCount))

        // --- GPU-local image ---
        let texture = try createRenderTexture(
            size: SIMD2(width, height),
            format: .b8g8r8a8Srgb,
            usages: [.sampled, .transferDst]
        )

        // --- One-time upload command buffer ---
        let pool = try context.device.createCommandPool(
            .init(flags: .transient, queueFamilyIndex: context.graphicsFamilyIndex))
        let cmd = try context.device.allocateCommandBuffers(
            .init(commandPool: pool, level: .primary, commandBufferCount: 1))[0]
        try cmd.begin(.init(flags: .oneTimeSubmit))

        let sub = ImageSubresourceRange(
            aspectMask: .color, baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0, layerCount: 1
        )
        let qf = context.graphicsFamilyIndex

        // UNDEFINED → TRANSFER_DST_OPTIMAL
        cmd.pipelineBarrier2(
            .init(imageMemoryBarriers: [
                ImageMemoryBarrier2(
                    srcStageMask: .none, srcAccessMask: [],
                    dstStageMask: .copy, dstAccessMask: .transferWrite,
                    oldLayout: .undefined, newLayout: .transferDstOptimal,
                    srcQueueFamilyIndex: qf, dstQueueFamilyIndex: qf,
                    image: texture.image, subresourceRange: sub)
            ]))

        // Buffer → Image
        cmd.copyBufferToImage(
            srcBuffer: staging.buffer,
            dstImage: texture.image,
            dstImageLayout: .transferDstOptimal,
            regions: [
                BufferImageCopy(
                    bufferOffset: 0, bufferRowLength: 0, bufferImageHeight: 0,
                    imageSubresource: ImageSubresourceLayers(
                        aspectMask: .color, mipLevel: 0, baseArrayLayer: 0, layerCount: 1),
                    imageOffset: Offset3D(x: 0, y: 0, z: 0),
                    imageExtent: Extent3D(width: width, height: height, depth: 1))
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
                    image: texture.image, subresourceRange: sub)
            ]))

        try cmd.end()

        // --- Submit immediately ---
        let uploadSemaphore = try context.device.createSemaphore()
        let fence = try context.device.createFence()
        try context.graphicsQueue.submit2(
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
            fence: fence
        )

        // free stagingn buffer
        self.releaseQueue.schedule(after: fence) {
            // staging.destroy()
            fence.destroy()
        }

        return GPUFuture(value: texture, semaphore: uploadSemaphore)
    }
}
