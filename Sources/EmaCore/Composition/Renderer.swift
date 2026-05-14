@preconcurrency import CVulkan
import Pointer

actor Renderer {
  private let device: GraphicsDevice
  private let surface: Surface
  private let compositionPipeline: CompositionPipeline

  private let vertexBuffer: GPUBuffer
  private let baseVertices: [VertexData]

  private let layerStorageBuffer: GPUBuffer
  private let layerStorage: LayerStorage

  private let defaultSampler: VkSampler

  private var frameIndex: UInt64 = 0

  private var swapchain: Swapchain {
    surface.configuredInfo!.swapchain
  }

  init(surface: Surface, device: GraphicsDevice) {
    self.device = device
    self.surface = surface
    // TODO: swinit: expose window size
    self.compositionPipeline = device.createCompositionPipeline(
      compatibleWith: surface.configuredInfo!.swapchain)

    self.layerStorageBuffer = device.createBuffer(
      size: UInt64(MemoryLayout<LayerStorageNode>.size) * 100000, usages: .storage)
    self.layerStorage = LayerStorage(layerStorageBuffer)

    var node = LayerStorageNode()
    node.shapeKind = .roundRect
    node.shape.roundedRect = .init(halfWidth: 30, halfHeight: 30, cornerRadius: 5, cornerDegree: 4)
    layerStorage.set(node, at: 0)

    self.vertexBuffer = device.createBuffer(
      size: UInt64(MemoryLayout<VertexData>.size) * 100000, usages: .vertex)

    self.baseVertices = [
      .init(layoutNodeIndex: 0, position: (0.0, 10.0)),
      .init(layoutNodeIndex: 0, position: (10.0, 10.0)),
      .init(layoutNodeIndex: 0, position: (10.0, 0.0)),
    ]
    let v = self.vertexBuffer.buffer.assumingMemoryBound(to: VertexData.self)
    _ = v.initialize(from: self.baseVertices)

    self.defaultSampler = createSamplers(device: device)
    let registry = TextureRegistry(
      on: device, globalDescriptorSetLayout: compositionPipeline.descriptorSetLayouts[0],
      imagesDescriptorSetLayout: compositionPipeline.descriptorSetLayouts[1])

    Task { [self] in
      let image = try! sample6(width: 500, height: 500)
      // let tex = await Texture(
      //   from: image, device: self.device, size: SIMD2(500, 500), usages: .static,
      //   queueIndex: UInt32(device.selectedQueueIndexes.graphics))

      while !Task.isCancelled {
        // await self.updateAnimatedVertices()
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

    var viewportSize = SIMD2<Float>(swapchain.imageSize)
    vkCmdPushConstants(
      commandBuffer, compositionPipeline.layout,
      VK_SHADER_STAGE_VERTEX_BIT.u32 | VK_SHADER_STAGE_FRAGMENT_BIT.u32, 0,
      2 * UInt32(MemoryLayout<Float>.size), &viewportSize)

    var viewport = VkViewport(
      x: 0,
      y: 0,
      width: Float(swapchain.imageSize.x),
      height: Float(swapchain.imageSize.y),
      minDepth: 0,
      maxDepth: 1
    )
    vkCmdSetViewport(commandBuffer, 0, 1, &viewport)

    var rects = [VkRect2D(offset: .init(), extent: swapchain.imageSize.asExtent)]
    vkCmdSetScissor(commandBuffer, 0, 1, &rects)

    var vertexBuffer: VkBuffer? = vertexBuffer.handle
    var p: UInt64 = 0
    vkCmdBindVertexBuffers(commandBuffer, 0, 1, &vertexBuffer, &p)

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

    await swapchainImage.present()
  }

  private func updateAnimatedVertices() {
    // Simple triangle movement: bounce horizontally using a sawtooth wave.
    let phase = Float(frameIndex % 240)
    let t = phase < 120 ? phase / 120.0 : (240.0 - phase) / 120.0
    let offsetX = (t * 2.0 - 1.0) * 0.5
    frameIndex &+= 1

    var animatedVertices = baseVertices
    animatedVertices[0].position = (
      baseVertices[0].position.0 + offsetX, baseVertices[0].position.1
    )
    animatedVertices[1].position = (
      baseVertices[1].position.0 + offsetX, baseVertices[1].position.1
    )
    animatedVertices[2].position = (
      baseVertices[2].position.0 + offsetX, baseVertices[2].position.1
    )

    let vertexPtr = vertexBuffer.buffer.assumingMemoryBound(to: VertexData.self)
    _ = vertexPtr.update(from: animatedVertices)
  }
}

// TODO: allow mipmap?
private func createSamplers(device: GraphicsDevice) -> VkSampler {
  var ci = with(VkSamplerCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
    $0.magFilter = VK_FILTER_LINEAR
    $0.minFilter = VK_FILTER_LINEAR
    $0.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR
    $0.addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT
    $0.addressModeV = VK_SAMPLER_ADDRESS_MODE_REPEAT
    $0.addressModeW = VK_SAMPLER_ADDRESS_MODE_REPEAT
    // $0.anisotropyEnable = VK_TRUE
  }

  var sampler: VkSampler?
  vkCreateSampler(device.handle, &ci, nil, &sampler).unwrap()

  return sampler!
}
