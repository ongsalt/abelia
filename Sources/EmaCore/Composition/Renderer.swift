@preconcurrency import CVulkan
import Pointer

actor Renderer {
  private let graphicsContext: GraphicsContext
  private let device: GraphicsDevice
  private let surface: Surface
  private let swapchain: Swapchain
  private let compositionPipeline: CompositionPipeline

  // private let layerStorage: LayerStorage

  init(graphicsContext: GraphicsContext, surface: Surface, device: GraphicsDevice) {
    self.graphicsContext = graphicsContext
    self.surface = surface
    // TODO: swinit: expose window size
    self.device = device
    self.swapchain = device.createSwapchain(for: surface)
    self.compositionPipeline = device.createCompositionPipeline(compatibleWith: swapchain)

    Task { [self] in
      while !Task.isCancelled {
        await self.render()
      }
    }
  }

  func requestFrameCallback(_ block: @Sendable () async -> Void) {

  }

  private func render() async {
    let swapchainImage = await swapchain.acquireNextImage()

    // TODO: reuse this. raii?
    let commandBuffer = device.commandBuffer
    var commandBufferBeginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pNext: nil,
      flags: 0,
      pInheritanceInfo: nil
    )
    vkBeginCommandBuffer(commandBuffer, &commandBufferBeginInfo).unwrap()


    // Transition the swapchain image
    swapchainImage.prepareRendering(commandBuffer: commandBuffer)

    let swapChainImageView = swapchainImage.imageView
    nonisolated(unsafe) let renderingAttachmentInfo = Box(VkRenderingAttachmentInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO
      $0.imageView = swapChainImageView
      $0.imageLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
      $0.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
      $0.storeOp = VK_ATTACHMENT_STORE_OP_STORE
      $0.clearValue.color.float32 = (0.0, 0.0, 0.0, 0.0)
    }

    var renderingInfo = with(VkRenderingInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_RENDERING_INFO
      $0.colorAttachmentCount = 1
      $0.layerCount = 1
      $0.pColorAttachments = renderingAttachmentInfo.ptr
      $0.renderArea = .init(offset: .init(), extent: swapchain.imageSize.asExtent)
    }
    vkCmdBeginRendering(commandBuffer, &renderingInfo)

    // MARK: actual rendering
    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, compositionPipeline.handle)

    // vkCmdSetScissor()
    var viewport = VkViewport(
      x: 0,
      y: 0,
      width: Float(swapchain.imageSize.x),
      height: Float(swapchain.imageSize.y),
      minDepth: 0,
      maxDepth: 1
    )
    vkCmdSetViewport(commandBuffer, 0, 1, &viewport)

    // TODO: dirty rect generation
    var rects = [VkRect2D(offset: .init(), extent: swapchain.imageSize.asExtent)]
    vkCmdSetScissor(commandBuffer, 0, 1, &rects)

    vkCmdDraw(commandBuffer, 3, 1, 0, 0)

    vkCmdEndRendering(commandBuffer)

    swapchainImage.preparePresent(commandBuffer: commandBuffer)

    vkEndCommandBuffer(commandBuffer).unwrap()

    // MARK: submit command buffer
    let presentCompletedSemaphore = swapchainImage.presentCompletedSemaphore
    let renderFinishedSemaphore = swapchainImage.renderFinishedSemaphore
    nonisolated(unsafe) let waitSemaphoreInfos = Box(VkSemaphoreSubmitInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO
      // we wait the same wait the same presentCompleteSemaphore that we notify
      $0.semaphore = presentCompletedSemaphore
      $0.stageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
    }
    nonisolated(unsafe) let signalSemaphoreInfo = Box(VkSemaphoreSubmitInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO
      $0.semaphore = renderFinishedSemaphore
    }
    let commandBufferInfo = Box(VkCommandBufferSubmitInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO
      $0.commandBuffer = commandBuffer
    }
    var submitInfo = with(VkSubmitInfo2()) {
      $0.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO_2
      $0.commandBufferInfoCount = 1
      $0.pCommandBufferInfos = commandBufferInfo.ptr
      // This entire task in queue wont happen until
      $0.waitSemaphoreInfoCount = 1
      $0.pWaitSemaphoreInfos = waitSemaphoreInfos.ptr

      $0.signalSemaphoreInfoCount = 1
      $0.pSignalSemaphoreInfos = signalSemaphoreInfo.ptr
    }
    vkQueueSubmit2(device.graphicsQueue, 1, &submitInfo, swapchainImage.inFlightFence).unwrap()

    swapchainImage.present()
  }
}
