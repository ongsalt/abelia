import Vulkan

// this should not be public in the final release
public protocol FrameSchedulerProtocol {
  func reconfigure() throws
  func render(body: (Image, ImageView, CommandBuffer, Int, SIMD2<UInt32>) -> Void) throws
  var swapchainImageFormat: Format { get }
  var swapchainImageColorSpace: ColorSpaceKHR { get }
}

// this is ugly
public final class FrameScheduler: FrameSchedulerProtocol {
  let surface: SurfaceKHR
  let context: DeviceContext
  let releaseQueue: ReleaseQueue = ReleaseQueue()

  public let swapchainImageFormat: Format
  public let swapchainImageColorSpace: ColorSpaceKHR
  var swapchain: SwapchainKHR
  var swapchainImages: [Image]
  var swapchainImageViews: [ImageView]

  static let maxFrameInFlightCount = 2
  private var currentFrameInFlightIndex: Int = 0
  var frameResources: [FrameResource]

  var currentFrameResource: FrameResource {
    frameResources[currentFrameInFlightIndex]
  }

  var lastFrameResource: FrameResource {
    frameResources[
      (currentFrameInFlightIndex - 1 + Self.maxFrameInFlightCount) % Self.maxFrameInFlightCount]
  }

  var width: UInt32
  var height: UInt32

  public init(
    context: DeviceContext, surface: SurfaceKHR, initialSize: SIMD2<UInt32> = SIMD2(800, 600)
  )
    throws(Vulkan.Result)
  {
    self.context = context
    self.surface = surface
    let physicalDevice = context.physicalDevice
    let device = context.device

    let caps = try physicalDevice.getSurfaceCapabilitiesKHR(surface: surface)
    let formats = try physicalDevice.getSurfaceFormatsKHR(surface: surface)

    self.swapchainImageFormat = .b8g8r8a8Unorm
    self.swapchainImageColorSpace = .srgbNonlinear

    // for surfaceFormat in formats {
    // let properties = physicalDevice.getFormatProperties(format: surfaceFormat.format)
    // print("\(surfaceFormat.format) in \(surfaceFormat.colorSpace):")
    // print(" - buffer: \(properties.bufferFeatures)")
    // print(" - linearTiling: \(properties.linearTilingFeatures)")
    // print(" - optimalTiling: \(properties.optimalTilingFeatures)")
    // print()
    // }

    let extent =
      if caps.currentExtent.width == UInt32.max {
        Extent2D(width: initialSize.x, height: initialSize.y)
      } else {
        caps.currentExtent
      }

    let (swapchain, images, views) = try Self.recreateSwapchain(
      device: device, surface: surface, caps: caps, imageFormat: swapchainImageFormat,
      colorspace: swapchainImageColorSpace, extent: extent)

    self.frameResources = try (0..<Self.maxFrameInFlightCount).map { i throws(Vulkan.Result) in
      try FrameResource(index: i, context: context)
    }

    self.swapchain = swapchain
    self.swapchainImages = images
    self.swapchainImageViews = views
    self.width = extent.width
    self.height = extent.height
  }

  public func waitForImage(reset: Bool = true) throws {
    try context.device.waitForFences(
      fences: [currentFrameResource.everythingCompletedFence], waitAll: true,
      timeout: UInt64.max)
    if reset {
      try context.device.resetFences(fences: [currentFrameResource.everythingCompletedFence])
    }
  }

  public func waitLastImage(reset: Bool = true) throws {
    let res = lastFrameResource
    try context.device.waitForFences(
      fences: [res.everythingCompletedFence], waitAll: true, timeout: UInt64.max)
    if reset {
      try context.device.resetFences(fences: [res.everythingCompletedFence])
    }
  }

  public func render(body: (Image, ImageView, CommandBuffer, Int, SIMD2<UInt32>) -> Void) throws {
    try self.waitForImage()

    self.releaseQueue.flush()

    let res = currentFrameResource
    currentFrameInFlightIndex = (currentFrameInFlightIndex + 1) % Self.maxFrameInFlightCount

    let imageIndex = try context.device.acquireNextImage2KHR(
      .init(
        swapchain: swapchain, timeout: UInt64.max,
        semaphore: res.imageAvailableSemaphore, deviceMask: 1
      )
    )

    try res.commandBuffer.reset()
    try res.commandBuffer.begin()

    let image = swapchainImages[Int(imageIndex)]
    let imageView = swapchainImageViews[Int(imageIndex)]
    // transition swapchain image to colorAttachmentOptimal
    res.commandBuffer.pipelineBarrier2(
      .init(imageMemoryBarriers: [
        .init(
          srcStageMask: .topOfPipe,
          srcAccessMask: .none,
          dstStageMask: .colorAttachmentOutput,
          dstAccessMask: [.colorAttachmentWrite, .colorAttachmentRead],
          oldLayout: .undefined,
          newLayout: .colorAttachmentOptimal,
          srcQueueFamilyIndex: 0,
          dstQueueFamilyIndex: 0,
          image: image,
          subresourceRange: .init(
            aspectMask: .color, baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0,
            layerCount: 1),
        )
      ]))

    body(
      image, imageView, res.commandBuffer, currentFrameInFlightIndex, SIMD2(self.width, self.height)
    )

    // transition it to presentSrcKHR
    res.commandBuffer.pipelineBarrier2(
      .init(imageMemoryBarriers: [
        .init(
          srcStageMask: .colorAttachmentOutput,
          srcAccessMask: [.colorAttachmentWrite, .colorAttachmentRead],
          dstStageMask: .bottomOfPipe,
          dstAccessMask: .none,
          oldLayout: .colorAttachmentOptimal,
          newLayout: .presentSrcKHR,
          srcQueueFamilyIndex: 0,
          dstQueueFamilyIndex: 0,
          image: image,
          subresourceRange: .init(
            aspectMask: .color,
            baseMipLevel: 0,
            levelCount: 1,
            baseArrayLayer: 0,
            layerCount: 1
          ),
        )
      ])
    )

    try res.commandBuffer.end()
    
    let graphicsSubmit = SubmitInfo2(
      waitSemaphoreInfos: [
        .init(
          semaphore: res.imageAvailableSemaphore, value: 0,
          stageMask: .colorAttachmentOutput, deviceIndex: 0
        )
      ],
      commandBufferInfos: [.init(commandBuffer: res.commandBuffer, deviceMask: 0)],
      signalSemaphoreInfos: [
        .init(
          semaphore: res.renderCompletedSemaphore, value: 0,
          stageMask: .colorAttachmentOutput, deviceIndex: 0
        )
      ]
    )

    try context.graphicsQueue.submit2(
      submits: [graphicsSubmit], fence: res.everythingCompletedFence)

    try context.graphicsQueue.presentKHR(
      .init(
        waitSemaphores: [res.renderCompletedSemaphore],
        swapchains: [swapchain],
        imageIndices: [imageIndex],
      )
    )
  }

  public func reconfigure() throws {
    try self.resize(w: 999999, h: 999999)
  }

  public func resize(w: UInt32, h: UInt32) throws {
    try recreateSwapchain(extent: Extent2D(width: w, height: h))
  }

  func recreateSwapchain(extent: Extent2D) throws(Vulkan.Result) {
    let caps = try context.physicalDevice.getSurfaceCapabilitiesKHR(surface: surface)
    print(caps)
    let clamped = extent.clamped(from: caps.minImageExtent, to: caps.maxImageExtent)
    self.width = clamped.width
    self.height = clamped.height
    
    nonisolated(unsafe) let prev = self.swapchain
    let previousSwapchainImageViews = self.swapchainImageViews
    (swapchain, swapchainImages, swapchainImageViews) = try Self.recreateSwapchain(
      device: context.device,
      surface: surface,
      caps: caps,
      imageFormat: swapchainImageFormat,
      colorspace: swapchainImageColorSpace,
      extent: clamped,
      previous: prev
    )

    self.releaseQueue.schedule(in: Self.maxFrameInFlightCount + 1) {
      for view in previousSwapchainImageViews {
        view.destroy()
      }
      prev.destroyKHR()
    }
  }

  private static func recreateSwapchain(
    device: Device, surface: SurfaceKHR, caps: SurfaceCapabilitiesKHR, imageFormat: Format,
    colorspace: ColorSpaceKHR, extent: Extent2D, previous: SwapchainKHR? = nil
  ) throws(Vulkan.Result) -> (SwapchainKHR, [Image], [ImageView]) {
    let swapchain = try device.createSwapchainKHR(
      .init(
        surface: surface,
        minImageCount: caps.minImageCount,
        imageFormat: imageFormat,
        imageColorSpace: colorspace,
        imageExtent: extent,
        imageArrayLayers: 1,
        imageUsage: .colorAttachment,
        imageSharingMode: .exclusive,
        preTransform: caps.currentTransform,
        compositeAlpha: {
          #if os(Linux)  // wayland
            .preMultiplied
          #else
            .opaque
          #endif
        }(),
        presentMode: .fifo,
        clipped: true,
        oldSwapchain: previous
      )
    )
    let swapchainImages = try swapchain.getImagesKHR()
    do {
      let swapchainImageViews = try swapchainImages.map { image in
        try device.createImageView(
          .init(
            image: image, viewType: .type2d, format: imageFormat,
            components: .init(r: .r, g: .g, b: .b, a: .a),
            subresourceRange: .init(
              aspectMask: .color, baseMipLevel: 0, levelCount: 1,
              baseArrayLayer: 0, layerCount: 1
            )
          )
        )
      }

      return (swapchain, swapchainImages, swapchainImageViews)
    } catch {
      throw error as! Vulkan.Result
    }
  }
}

class FrameResource {
  let index: Int
  let commandPool: CommandPool
  let commandBuffer: CommandBuffer

  let renderCompletedSemaphore: Semaphore
  let imageAvailableSemaphore: Semaphore
  let everythingCompletedFence: Fence

  init(index: Int, context: borrowing DeviceContext) throws(Vulkan.Result) {
    let commandPool = try context.device.createCommandPool(
      .init(flags: .resetCommandBuffer, queueFamilyIndex: context.graphicsFamilyIndex))
    let commandBuffer = try context.device.allocateCommandBuffers(
      .init(commandPool: commandPool, level: .primary, commandBufferCount: 1))

    self.index = index
    self.commandPool = commandPool
    self.commandBuffer = commandBuffer[0]
    self.renderCompletedSemaphore = try context.device.createSemaphore()
    self.imageAvailableSemaphore = try context.device.createSemaphore()
    self.everythingCompletedFence = try context.device.createFence(.init(flags: .signaled))
  }
}
