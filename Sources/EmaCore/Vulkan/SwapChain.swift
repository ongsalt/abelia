@preconcurrency import CVulkan
import Foundation
import Pointer

public class Swapchain: @unchecked Sendable {
  private let surface: Surface
  private let device: GraphicsDevice
  private var handle: VkSwapchainKHR

  // swapchain images
  private var images: [VkImage]
  private var imageViews: [VkImageView]

  // Per swapchain image (total texture we have)
  private var renderFinishedSemaphores: [VkSemaphore]

  // subset of above, we want to use only 2 (or 3) concurrently
  private var presentCompletedSemaphores: [VkSemaphore]
  private var inFlightFences: [VkFence]
  private var currentFrameInFlightIndex: Int = 0

  static let maxFramesInFlight = 1

  private(set) var imageFormat: VkFormat
  private(set) var imageSize: SIMD2<UInt32>

  init(
    for surface: Surface, on device: GraphicsDevice, initialSize size: SIMD2<UInt32>,
    surfaceCapabilities: VkSurfaceCapabilitiesKHR
  ) {
    self.surface = surface
    self.device = device
    let swapchain = createSwapchain(
      for: surface.handle, on: device, size: size, capabilities: surfaceCapabilities)
    self.handle = swapchain

    let imageFormat = VK_FORMAT_B8G8R8A8_UNORM

    self.images = Vulkan.enumerate { count, arr in
      vkGetSwapchainImagesKHR(device.handle, swapchain, count, arr)
    }.compactMap { $0 }
    self.imageViews = images.map {
      createImageView(device: device.handle, image: $0, format: imageFormat)
    }

    // TODO: actually selecting format
    self.imageFormat = imageFormat
    // we shuold actually query window size then clamp it to capabilities.[min|max]ImageExtent
    self.imageSize = size

    self.renderFinishedSemaphores = (0..<images.count).map { _ in
      createSemaphore(device: device.handle)
    }
    self.presentCompletedSemaphores = (0..<Self.maxFramesInFlight).map { _ in
      createSemaphore(device: device.handle)
    }
    self.inFlightFences = (0..<Self.maxFramesInFlight).map { _ in
      createFence(device: device.handle, signaled: true)
    }
  }

  // async maybe?
  public func acquireNextImage() async -> SwapchainImage {
    let inFlightFence = self.inFlightFences[currentFrameInFlightIndex]
    await device.wait(for: inFlightFence)

    nonisolated(unsafe) var swapchainImageIndex: UInt32 = 0
    nonisolated(unsafe) let deviceHandle = device.handle
    nonisolated(unsafe) let handle = self.handle
    nonisolated(unsafe) let presentCompletedSemaphore = self.presentCompletedSemaphores[
      currentFrameInFlightIndex]

    let res = await withUnsafeContinuation { continuation in
      DispatchQueue.global(qos: .background).async {
        let res = vkAcquireNextImageKHR(
          deviceHandle,
          handle,
          UInt64.max,  // timeout nanosec
          presentCompletedSemaphore,  // the one to NOTIFY after we are done
          nil,
          &swapchainImageIndex
        )
        continuation.resume(returning: res)
      }
    }

    if res == VK_SUBOPTIMAL_KHR {
      await self.recreate()
      return await self.acquireNextImage()
    } else {
      res.unwrap()
    }

    self.currentFrameInFlightIndex = (self.currentFrameInFlightIndex + 1) % Self.maxFramesInFlight

    return SwapchainImage(
      image: images[Int(swapchainImageIndex)],
      imageView: imageViews[Int(swapchainImageIndex)],
      imageIndex: swapchainImageIndex,
      renderFinishedSemaphore: self.renderFinishedSemaphores[Int(swapchainImageIndex)],
      presentCompletedSemaphore: presentCompletedSemaphore,
      inFlightFence: inFlightFence,
      swapChainHandle: self.handle,
      presentQueue: device.presentQueue
    )
  }

  func recreate() async {
    await device.waitIdle()

    self.surface.reconfigure()
    let capabilities = surface.configuredInfo!.capabilities
    let size = capabilities.currentExtent.asSimd

    let prev = self.handle
    let prevImageViews = imageViews

    self.handle = createSwapchain(for: surface.handle, on: device, size: size, capabilities: capabilities, previous: prev)
    self.imageSize = size

    for view in prevImageViews {
      vkDestroyImageView(device.handle, view, nil)
    }

    self.images = Vulkan.enumerate { count, arr in
      vkGetSwapchainImagesKHR(device.handle, self.handle, count, arr)
    }.compactMap { $0 }
    self.imageViews = images.map {
      createImageView(device: device.handle, image: $0, format: imageFormat)
    }
  }
}

private func createImageView(device: VkDevice, image: VkImage, format: VkFormat) -> VkImageView {
  var ci = VkImageViewCreateInfo(
    sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    pNext: nil,
    flags: 0,
    image: image,
    viewType: VK_IMAGE_VIEW_TYPE_2D,
    format: format,
    components: VkComponentMapping(  // well this can be zeroed out
      r: VK_COMPONENT_SWIZZLE_IDENTITY,
      g: VK_COMPONENT_SWIZZLE_IDENTITY,
      b: VK_COMPONENT_SWIZZLE_IDENTITY,
      a: VK_COMPONENT_SWIZZLE_IDENTITY
    ),
    subresourceRange: .init(
      aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.u32,
      baseMipLevel: 0,
      levelCount: 1,
      baseArrayLayer: 0,
      layerCount: 1
    )
  )

  var imageView: VkImageView?
  vkCreateImageView(device, &ci, nil, &imageView).unwrap()

  return imageView!
}

private func createSwapchain(
  for surface: VkSurfaceKHR,
  on device: GraphicsDevice,
  size: SIMD2<UInt32>,
  capabilities: VkSurfaceCapabilitiesKHR,
  previous: VkSwapchainKHR? = nil
) -> VkSwapchainKHR {

  let pQueueFamilyIndices = CArray([
    UInt32(device.selectedQueueIndexes.graphics),
    UInt32(device.selectedQueueIndexes.present),
  ])
  var ci = with(VkSwapchainCreateInfoKHR()) {
    $0.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
    $0.oldSwapchain = previous
    $0.surface = surface
    $0.minImageCount = (capabilities.minImageCount + 1).clamped(
      capabilities.minImageCount, capabilities.maxImageCount)  // TODO: get this from what device reported

    $0.imageExtent = size.asExtent
    // TODO: check support
    $0.imageFormat = VK_FORMAT_B8G8R8A8_UNORM
    $0.imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
    $0.imageArrayLayers = 1  // ???wtf
    $0.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.u32

    // gauranteed support
    $0.presentMode = VK_PRESENT_MODE_FIFO_KHR
    // mailbox if we want to do triple buffering

    #if os(Windows)
      // fuck windows
      $0.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
    #else
      $0.compositeAlpha = VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR
    #endif

    if device.presentQueue == device.graphicsQueue {
      $0.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
    } else {
      $0.imageSharingMode = VK_SHARING_MODE_CONCURRENT
      $0.queueFamilyIndexCount = pQueueFamilyIndices.count
      $0.pQueueFamilyIndices = pQueueFamilyIndices.ptr
    }

    // TODO: get this from device support
    $0.preTransform = capabilities.currentTransform
    $0.clipped = true
  }

  var swapchain: VkSwapchainKHR?
  vkCreateSwapchainKHR(
    device.handle,
    &ci,
    nil,
    &swapchain
  ).unwrap()

  return swapchain!
}

private func createSemaphore(device: VkDevice) -> VkSemaphore {
  var semaphore: VkSemaphore?

  var ci = with(VkSemaphoreCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
  }
  vkCreateSemaphore(device, &ci, nil, &semaphore).unwrap()
  return semaphore!
}

private func createFence(device: VkDevice, signaled: Bool = false) -> VkFence {
  var fence: VkFence?
  var ci = with(VkFenceCreateInfo()) {
    $0.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
    $0.flags = if signaled { VK_FENCE_CREATE_SIGNALED_BIT.u32 } else { 0 }
  }
  vkCreateFence(device, &ci, nil, &fence).unwrap()
  return fence!
}

public struct SwapchainImage: ~Copyable {
  let image: VkImage
  let imageView: VkImageView
  let imageIndex: UInt32
  let renderFinishedSemaphore: VkSemaphore
  let presentCompletedSemaphore: VkSemaphore
  let inFlightFence: VkFence
  let swapChainHandle: VkSwapchainKHR
  let presentQueue: VkQueue

  public func prepareRendering(commandBuffer: VkCommandBuffer) {
    let image = image
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

      $0.srcStageMask = TextureLayout.undefined.stageMask
      $0.srcAccessMask = TextureLayout.undefined.accessMask
      $0.oldLayout = TextureLayout.undefined.vkLayout

      $0.dstStageMask = TextureLayout.renderAttachment.stageMask
      $0.dstAccessMask = TextureLayout.renderAttachment.accessMask
      $0.newLayout = TextureLayout.renderAttachment.vkLayout
    }

    var dependencyInfo = with(VkDependencyInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
      $0.imageMemoryBarrierCount = 1
      $0.pImageMemoryBarriers = barrier.ptr
    }

    vkCmdPipelineBarrier2(commandBuffer, &dependencyInfo)
  }

  public func preparePresent(commandBuffer: VkCommandBuffer) {
    let image = image
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

      $0.srcStageMask = TextureLayout.renderAttachment.stageMask
      $0.srcAccessMask = TextureLayout.renderAttachment.accessMask
      $0.oldLayout = TextureLayout.renderAttachment.vkLayout

      $0.dstStageMask = VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT  // ???
      $0.dstAccessMask = VK_ACCESS_2_NONE
      $0.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    }

    var dependencyInfo = with(VkDependencyInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
      $0.imageMemoryBarrierCount = 1
      $0.pImageMemoryBarriers = barrier.ptr
    }

    vkCmdPipelineBarrier2(commandBuffer, &dependencyInfo)
  }

  public consuming func present() {
    let imageIndex = Box(imageIndex)
    let handle = Box<VkSwapchainKHR?>(swapChainHandle)
    let renderFinishedSemaphore = Box<VkSemaphore?>(renderFinishedSemaphore)

    var info = VkPresentInfoKHR(
      sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
      pNext: nil,
      waitSemaphoreCount: 1,
      pWaitSemaphores: renderFinishedSemaphore.ptr,
      swapchainCount: 1,
      pSwapchains: handle.ptr,
      pImageIndices: imageIndex.ptr,
      pResults: nil,
    )

    vkQueuePresentKHR(presentQueue, &info).expect("Cannot present image[\(self.imageIndex)]")
    // TODO: this notify that swapchain is out of date due to resize or someshi
  }
}
