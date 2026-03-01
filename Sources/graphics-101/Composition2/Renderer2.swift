@preconcurrency import CVMA
import Foundation
import Wayland  // for pointers

class Renderer2 {
    let state: VulkanState
    let pipeline: TexturePipeline
    let renderTexture: RenderTexture
    let buffer: RawGPUBuffer
    let indexOffset: Int
    let textureRegistry: RenderTextureRegistry
    let uniformBuffer: GPUBuffer<(Float32, Float32)>

    init(state: VulkanState) async {
        self.state = state
        self.textureRegistry = RenderTextureRegistry(vulkan: state)
        self.renderTexture = textureRegistry.newRenderTarget(size: state.swapChain.extent.simd2)

        self.pipeline = TexturePipeline(state: state, textureRegistry: textureRegistry)

        self.buffer = RawGPUBuffer(allocator: state.allocator, device: state.device)
        self.uniformBuffer = GPUBuffer(
            data: [(800, 600)],
            allocator: state.allocator,
            device: state.device,
            count: 1,
            usages: VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT
        )

        let textRenderer = TextRenderer()
        let t = "Hi hi kroos desu yo"
        let (_, ink) = textRenderer.measure(text: t)
        let ww = ink.width * 2
        let hh = ink.height * 2
        let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(
            capacity: Int(hh * ww))
        buffer.initialize(repeating: 0)
        _ = textRenderer.render(t, to: buffer, width: ww, height: hh)
        Log.debug(.vulkan, "Text dimension: \(ink)")

        // for byte in buffer {
        //     print(byte, terminator: " ")
        // }
        // print()

        // TODO: properly map coord, i should just use normal coord everywhere and transform it later in the shader
        // 0..800 map to -1..1
        let w = Float(ww)
        let h = Float(hh)

        let indexes: [UInt32] = [0, 1, 2, 0, 3, 2]
        let vertexData: [TextureVertexData] = [
            .init(sizing: [0, 0, w, h], textureData: [1, 0, 0, 0], position: [0, 0]),
            .init(sizing: [0, 0, w, h], textureData: [1, 0, 0, 0], position: [0, h]),
            .init(sizing: [0, 0, w, h], textureData: [1, 0, 0, 0], position: [w, h]),
            .init(sizing: [0, 0, w, h], textureData: [1, 0, 0, 0], position: [w, 0]),
        ]
        var offset = self.buffer.write(vertexData)
        self.indexOffset = offset
        offset += self.buffer.write(indexes, offset: offset)

        let textTexture = await textureRegistry.createStaticTexture(
            from: buffer,
            size: [UInt32(ww), UInt32(hh)],
            format: VK_FORMAT_R8_UNORM
        )

        Log.debug(.vulkan, "\(textureRegistry.textures)")
    }

    private func waitForImage(offThread: Bool = true) async {
        let swapChain = state.swapChain
        let frameIndex = swapChain.frameIndex

        // TODO: epoll/DispatchSource.makeReadSource
        if offThread {
            struct TrustMeBro: @unchecked Sendable {
                var fence: VkFence?
                var device: VkDevice
            }

            let c = TrustMeBro(fence: swapChain.fences[frameIndex], device: state.device)

            await withUnsafeContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async { [c] in
                    var c = c
                    vkWaitForFences(c.device, 1, &c.fence, true, UInt64.max).unwrap()
                    continuation.resume()
                }
            }
        } else {
            swapChain.waitForFence(frameIndex: frameIndex)
        }

        swapChain.resetFence(frameIndex: frameIndex)
    }

    private func acquireNextImage() async -> (VkImage, VkImageView, UInt32) {
        await withUnsafeContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [state] in
                let res = state.swapChain.acquireNextImage()
                continuation.resume(returning: res)
            }
        }
    }

    func perform(
        _ commands: [LayerGrouping] = []
    ) async -> Bool {
        let swapChain = state.swapChain
        let frameIndex = swapChain.frameIndex

        await waitForImage()
        let (image, imageView, imageIndex) = await acquireNextImage()

        // Set viewport and scissor
        let commandBuffer = state.commandBuffers[frameIndex]
        vkResetCommandBuffer(commandBuffer, 0).unwrap()
        var commandBufferCI = with(VkCommandBufferBeginInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
            $0.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.rawValue
        }
        vkBeginCommandBuffer(commandBuffer, &commandBufferCI).unwrap()

        // // Transition swapchain image to attachment optimal layout
        let imageBarrier = Pin([
            with(VkImageMemoryBarrier2()) {
                $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
                $0.srcStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
                $0.srcAccessMask = 0
                $0.dstStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
                $0.dstAccessMask =
                    VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT
                $0.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED
                $0.newLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
                $0.image = image
                $0.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
                $0.subresourceRange.levelCount = 1
                $0.subresourceRange.layerCount = 1
            },
            VkImageMemoryBarrier2(
                sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
                pNext: nil,
                srcStageMask: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
                srcAccessMask: 0,
                dstStageMask: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
                dstAccessMask: VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT
                    | VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
                oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
                newLayout: VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL,
                srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,  // ignore
                dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,  // ignore
                image: self.renderTexture.image,
                subresourceRange: .init(
                    aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                    baseMipLevel: 0,
                    levelCount: 1,
                    baseArrayLayer: 0,
                    layerCount: 1
                )
            ),
        ])

        let dependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
            $0.pImageMemoryBarriers = imageBarrier.readonly
        }

        vkCmdPipelineBarrier2(commandBuffer, dependencyInfo.ptr)

        // Setup rendering attachment
        let colorAttachmentInfo = Box(VkRenderingAttachmentInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO
            $0.imageView = self.renderTexture.view
            $0.imageLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
            $0.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
            $0.storeOp = VK_ATTACHMENT_STORE_OP_STORE
            $0.clearValue.color.float32 = (0.1, 0.0, 0.0, 1.0)

            $0.resolveMode = VK_RESOLVE_MODE_AVERAGE_BIT
            $0.resolveImageView = imageView
            $0.resolveImageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }

        let renderingInfo = Box(VkRenderingInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_RENDERING_INFO
            $0.renderArea.extent = swapChain.extent
            $0.layerCount = 1
            $0.colorAttachmentCount = 1
            $0.pColorAttachments = colorAttachmentInfo.readonly
        }

        // actual rendering
        vkCmdBeginRendering(commandBuffer, renderingInfo.ptr)

        setViewport(swapChain.extent.simd2, commandBuffer: commandBuffer)
        pipeline.bind(commandBuffer: commandBuffer)

        var offsets: UInt64 = 0
        vkCmdBindVertexBuffers(commandBuffer, 0, 1, &buffer.buffer, &offsets)
        vkCmdBindIndexBuffer(
            commandBuffer, buffer.buffer, UInt64(indexOffset), VK_INDEX_TYPE_UINT32)

        var address: SIMD2<UInt32> = [800, 600]
        vkCmdPushConstants(
            commandBuffer, pipeline.pipelineLayout, VK_SHADER_STAGE_VERTEX_BIT.rawValue | VK_SHADER_STAGE_FRAGMENT_BIT.rawValue,
            0,
            UInt32(MemoryLayout<SIMD2<UInt32>>.size),
            &address
        )

        var descriptorSet: VkDescriptorSet? = textureRegistry.descriptorSet
        vkCmdBindDescriptorSets(
            commandBuffer,
            VK_PIPELINE_BIND_POINT_GRAPHICS,
            pipeline.pipelineLayout,
            0,
            1,
            &descriptorSet,
            0,
            nil
        )

        vkCmdDrawIndexed(commandBuffer, 6, 1, 0, 0, 0)
        vkCmdEndRendering(commandBuffer)

        // Transition image to present
        let barrierPresent = Box(VkImageMemoryBarrier2()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
            $0.srcStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
            $0.srcAccessMask = VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT
            $0.dstStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
            $0.dstAccessMask = 0
            $0.oldLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
            $0.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
            $0.image = image
            $0.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
            $0.subresourceRange.levelCount = 1
            $0.subresourceRange.layerCount = 1
        }

        let barrierPresentDependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
            $0.pImageMemoryBarriers = barrierPresent.readonly
        }

        vkCmdPipelineBarrier2(commandBuffer, barrierPresentDependencyInfo.ptr)

        vkEndCommandBuffer(commandBuffer).unwrap()

        // Submit
        let waitStages = Box(
            VkPipelineStageFlags(
                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue))
        let presentSemaphore = Box(
            optional: swapChain.presentSemaphores[frameIndex])
        let renderSemaphore = Box(
            optional: swapChain.renderSemaphore[Int(imageIndex)])
        let commandBufferPtr = Box(optional: commandBuffer)

        let submitInfo = Box(VkSubmitInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
            $0.waitSemaphoreCount = 1
            // wont start rendering until current frame in presented
            $0.pWaitSemaphores = presentSemaphore.readonly
            $0.pWaitDstStageMask = waitStages.readonly
            $0.commandBufferCount = 1
            $0.pCommandBuffers = commandBufferPtr.readonly
            $0.signalSemaphoreCount = 1
            $0.pSignalSemaphores = renderSemaphore.readonly
        }

        vkQueueSubmit(state.graphicsQueue, 1, submitInfo.ptr, swapChain.fences[frameIndex])
            .unwrap()
        // present

        let swapchainHandle: Box<VkSwapchainKHR?> = Box(swapChain.swapChain)
        let imageIndexCopy = Box(imageIndex)

        let presentInfo = Box(VkPresentInfoKHR()) {
            $0.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
            $0.waitSemaphoreCount = 1
            $0.pWaitSemaphores = renderSemaphore.readonly
            $0.swapchainCount = 1
            $0.pSwapchains = swapchainHandle.readonly
            $0.pImageIndices = imageIndexCopy.readonly
        }

        // should this be in the main queue tho
        vkQueuePresentKHR(state.presentQueue, presentInfo.ptr).unwrap()
        swapChain.frameIndex = (swapChain.frameIndex + 1) % swapChain.framesInFlightCount

        return true
    }

    private func render(to target: RenderTexture, commandBuffer: VkCommandBuffer) {

    }

    private func setViewport(_ size: SIMD2<UInt32>, commandBuffer: VkCommandBuffer) {
        var viewport = VkViewport(
            x: 0,
            y: 0,
            width: Float(size.x),
            height: Float(size.y),
            minDepth: 0.0,
            maxDepth: 1.0
        )
        vkCmdSetViewport(commandBuffer, 0, 1, &viewport)

        var scissor = VkRect2D(
            offset: VkOffset2D(x: 0, y: 0),
            extent: .init(width: size.x, height: size.y)
        )
        vkCmdSetScissor(commandBuffer, 0, 1, &scissor)
    }

    private func cmdWaitLayerRendereing(commandBuffer: VkCommandBuffer, image: VkImage) {
        let imageBarrier = Box(VkImageMemoryBarrier2()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
            $0.srcStageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
            $0.srcAccessMask = 0
            $0.dstStageMask = VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT
            $0.dstAccessMask =
                VK_ACCESS_2_SHADER_SAMPLED_READ_BIT
            $0.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED
            $0.newLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
            $0.image = image
            $0.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
            $0.subresourceRange.levelCount = 1
            $0.subresourceRange.layerCount = 1
        }

        let dependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
            $0.pImageMemoryBarriers = imageBarrier.readonly
        }

        vkCmdPipelineBarrier2(commandBuffer, dependencyInfo.ptr)
    }
}
