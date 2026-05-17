@preconcurrency import CVulkan
import Pointer
import Synchronization

class Renderer: @unchecked Sendable {
  private let device: GraphicsDevice
  private let surface: Surface
  private let compositionPipeline: CompositionPipeline

  private let vertexBuffer: GPUBuffer
  private let indexBuffer: GPUBuffer
  private let baseVertices: [VertexData]

  // TODO: rename this to renderNodeStorage or shi
  private let layerStorageBuffer: GPUBuffer
  private let layerStorage: LayerStorage

  nonisolated(unsafe) let textureRegistry: TextureRegistry

  // private var acquiredFrame: SwapchainImage?

  private var swapchain: any SwapchainProtocol

  init(surface: Surface, device: GraphicsDevice) {
    self.device = device
    self.surface = surface
    self.swapchain = surface.configuredInfo!.swapchain

    self.layerStorageBuffer = device.createBuffer(
      size: UInt64(MemoryLayout<LayerStorageNode>.size) * 100000, usages: .storage)
    self.layerStorage = LayerStorage(layerStorageBuffer)

    self.compositionPipeline = CompositionPipeline(
      device: device, format: swapchain.imageFormat, layerStorage: layerStorage,
      layerStorageBuffer: layerStorageBuffer)

    var node = LayerStorageNode()
    node.shapeKind = .roundRect
    node.shape.roundedRect = .init(halfWidth: 30, halfHeight: 30, cornerRadius: 5, cornerDegree: 4)
    layerStorage.set(node, at: 0)

    self.vertexBuffer = device.createBuffer(
      size: UInt64(MemoryLayout<VertexData>.size) * 100000, usages: .vertex)

    self.indexBuffer = device.createBuffer(
      size: UInt64(MemoryLayout<UInt32>.size) * 6 * 100000, usages: .index)

    self.baseVertices = [
      .init(layoutNodeIndex: 0, position: (0.0, 0.0)),
      .init(layoutNodeIndex: 0, position: (0.0, 500.0)),
      .init(layoutNodeIndex: 0, position: (500.0, 0.0)),
      .init(layoutNodeIndex: 0, position: (500.0, 500.0)),
    ]

    // let v = self.vertexBuffer.buffer.assumingMemoryBound(to: VertexData.self)
    // _ = v.initialize(from: self.baseVertices)

    // _ = self.indexBuffer.buffer.assumingMemoryBound(to: UInt32.self).initialize(from: [
    //   0, 1, 2, 1, 2, 3,
    // ])

    self.textureRegistry = TextureRegistry(
      on: device, globalDescriptorSetLayout: compositionPipeline.descriptorSetLayouts[0],
      imagesDescriptorSetLayout: compositionPipeline.descriptorSetLayouts[1])

  }

  // TODO: remove @MainActor after we are writing layerStorageNode in createBatch
  @MainActor
  public func update(dirtyRects: [Rect], dirtyLayers: [Layer], batches: [Batch]) {
    for layer in dirtyLayers {
      self.layerStorage.update(layer)
    }

    let indexBuffer = indexBuffer.buffer.assumingMemoryBound(to: UInt32.self)
    var ii = 0
    let vertexBuffer = vertexBuffer.buffer.assumingMemoryBound(to: VertexData.self)
    var iv = 0

    for batch in batches {
      if case .composite(let layers) = batch.subpasses[0].inner {
        for layer in layers {
          let index = self.layerStorage.index(of: layer)
          let bound = layer.boundingRect
          // print(layer, bound)
          vertexBuffer[iv] = VertexData(
            layoutNodeIndex: UInt32(index), position: bound.topLeft.asTuple)
          vertexBuffer[iv + 1] = VertexData(
            layoutNodeIndex: UInt32(index),
            position: (bound.topLeft + SIMD2(bound.size.x, 0)).asTuple)
          vertexBuffer[iv + 2] = VertexData(
            layoutNodeIndex: UInt32(index),
            position: (bound.topLeft + SIMD2(0, bound.size.y)).asTuple)
          vertexBuffer[iv + 3] = VertexData(
            layoutNodeIndex: UInt32(index), position: (bound.topLeft + bound.size).asTuple)

          indexBuffer[ii] = UInt32(iv)
          indexBuffer[ii + 1] = UInt32(iv) + 1
          indexBuffer[ii + 2] = UInt32(iv) + 2
          indexBuffer[ii + 3] = UInt32(iv) + 1
          indexBuffer[ii + 4] = UInt32(iv) + 2
          indexBuffer[ii + 5] = UInt32(iv) + 3

          ii += 6
          iv += 3
        }
      }
    }
  }

  func render() {
    // TODO: swapchain.oudated

    // TODO: reuse this. raii?
    let commandBuffer = device.commandBuffer
    // we shuold reset this once in a while?
    var commandBufferBeginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pNext: nil,
      flags: 0,
      pInheritanceInfo: nil
    )
    vkBeginCommandBuffer(commandBuffer, &commandBufferBeginInfo).unwrap()

    swapchain.waitForNextImage()
    let swapchainImage = swapchain.acquireNextImage(commandBuffer: commandBuffer)

    // TODO: update vertex buffer
    writeRenderingCommand(
      to: commandBuffer, attachmentView: swapchainImage.imageView, clear: true, store: true,
      indexCount: 6, firstIndex: 0)

    swapchainImage.transitionToPresentable()
    
    vkEndCommandBuffer(commandBuffer).unwrap()

    // MARK: submit command buffer
    let presentCompletedSemaphore = swapchainImage.presentCompletedSemaphore
    let renderFinishedSemaphore = swapchainImage.renderFinishedSemaphore
    let waitSemaphoreInfos = Box(VkSemaphoreSubmitInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO
      // we wait the same wait the same presentCompleteSemaphore that we notify
      $0.semaphore = presentCompletedSemaphore
      $0.stageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
    }
    let signalSemaphoreInfo = Box(VkSemaphoreSubmitInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO
      $0.semaphore = renderFinishedSemaphore
      $0.value = swapchainImage.timelineValue ?? 0
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

    // this one should only be specific to Vulkan implementation
    vkQueueSubmit2(device.graphicsQueue, 1, &submitInfo, swapchainImage.inFlightFence).unwrap()

    swapchainImage.present()
  }

  public func forceRenderAfterResize() {
    // TODO: VK_EXT_swapchain_maintenance1
    // use directx swapchain?
    self.swapchain.recreate()
    self.render()
  }

  private func writeRenderingCommand(
    to commandBuffer: VkCommandBuffer, attachmentView: VkImageView, clear: Bool = true,
    store: Bool = true,
    indexCount: UInt32,
    firstIndex: UInt32,
    // resolveTo resolveTarget:,

  ) {
    nonisolated(unsafe) let renderingAttachmentInfo = Box(VkRenderingAttachmentInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO
      $0.imageView = attachmentView
      $0.imageLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL

      if store {
        $0.storeOp = VK_ATTACHMENT_STORE_OP_STORE
      } else {
        $0.storeOp = VK_ATTACHMENT_STORE_OP_NONE
      }

      if clear {
        $0.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
        $0.clearValue.color.float32 = (0.0, 0.0, 0.0, 0.0)
      } else {
        $0.loadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
      }
    }

    var renderingInfo = with(VkRenderingInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_RENDERING_INFO
      $0.colorAttachmentCount = 1
      $0.layerCount = 1
      $0.pColorAttachments = renderingAttachmentInfo.ptr
      $0.renderArea = .init(offset: .init(), extent: swapchain.size.asExtent)
    }
    vkCmdBeginRendering(commandBuffer, &renderingInfo)

    // MARK: actual rendering
    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, compositionPipeline.handle)

    // bind those 2 set
    var descriptorSets: [VkDescriptorSet?] = [
      compositionPipeline.globalDescriptorSet,
      textureRegistry.imagesDescriptorSet,
    ]

    var tf: UInt32 = 0
    vkCmdBindDescriptorSets(
      commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, compositionPipeline.layout, 0,
      UInt32(descriptorSets.count), &descriptorSets, 0, &tf)

    var viewportSize = SIMD2<Float>(swapchain.size)
    vkCmdPushConstants(
      commandBuffer, compositionPipeline.layout,
      VK_SHADER_STAGE_VERTEX_BIT.u32 | VK_SHADER_STAGE_FRAGMENT_BIT.u32, 0,
      2 * UInt32(MemoryLayout<Float>.size), &viewportSize)

    var viewport = VkViewport(
      x: 0,
      y: 0,
      width: Float(swapchain.size.x),
      height: Float(swapchain.size.y),
      minDepth: 0,
      maxDepth: 1
    )
    vkCmdSetViewport(commandBuffer, 0, 1, &viewport)

    var rects = [VkRect2D(offset: .init(), extent: swapchain.size.asExtent)]
    vkCmdSetScissor(commandBuffer, 0, 1, &rects)

    // same one
    var vertexBuffer: VkBuffer? = vertexBuffer.handle
    var p: UInt64 = 0
    vkCmdBindVertexBuffers(commandBuffer, 0, 1, &vertexBuffer, &p)

    vkCmdBindIndexBuffer(commandBuffer, self.indexBuffer.handle, 0, VK_INDEX_TYPE_UINT32)

    // vkCmdDraw(commandBuffer, 3, 1, 0, 0)
    vkCmdDrawIndexed(commandBuffer, indexCount, 1, firstIndex, 0, 0)

    vkCmdEndRendering(commandBuffer)
  }
}
