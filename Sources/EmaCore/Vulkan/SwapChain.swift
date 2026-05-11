@preconcurrency import CVulkan
import Pointer

public class Swapchain {
  private let surface: Surface
  private let device: GraphicsDevice
  private var handle: VkSwapchainKHR
  private var currentSwapchainImageIndex: Int = 0
  private var images: [VkImage]
  private var imageViews: [VkImageView]

  private(set) var imageFormat: VkFormat
  private(set) var imageSize: SIMD2<UInt32>
  // no triple buffering for now, tripleBuffering = 2
  static let maxFramesInFlight = 1

  private(set) var size: Size<UInt32>

  init(for surface: Surface, on device: GraphicsDevice, size: Size<UInt32>) {
    self.surface = surface
    self.device = device
    let swapchain = createSwapchain(for: surface, on: device, size: size)
    self.handle = swapchain
    self.size = size

    let imageFormat = VK_FORMAT_B8G8R8A8_UNORM

    let images = Vulkan.enumerate { count, arr in
      vkGetSwapchainImagesKHR(device.handle, swapchain, count, arr)
    }.compactMap { $0 }
    self.images = images
    self.imageViews = images.map {
      createImageView(device: device.handle, image: $0, format: imageFormat)
    }

    // TODO: actually selecting format
    self.imageFormat = imageFormat
    // we shuold actually query window size then clamp it to capabilities.[min|max]ImageExtent
    self.imageSize = size
  }

  public func acquireNextImage() -> SwapchainImage {
    // var index: UInt32 = 0
    // vkAcquireNextImageKHR(
    //   device.handle,
    //   self.handle,
    //   1600, // timeout nanosec
    //   VkSemaphore?,
    //   VkFence?,
    //   &index
    // )

    return SwapchainImage(
      imageIndex: 67,
      renderCompletedSemaphore: VkSemaphore(bitPattern: 67)!,
      swapChainHandle: handle,
      presentQueue: device.presentQueue
    )
  }

  func recreate(size: Size<UInt32>) {
    let prev = self.handle
    self.handle = createSwapchain(for: surface, on: device, size: size, previous: prev)
    self.size = size
    destroySwapchain(prev)
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
    components: VkComponentMapping( // well this can be zeroed out
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
  for surface: Surface,
  on device: GraphicsDevice,
  size: Size<UInt32>,
  previous: VkSwapchainKHR? = nil
) -> VkSwapchainKHR {

  let pQueueFamilyIndices = CArray([
    UInt32(device.selectedQueueIndexes.graphics),
    UInt32(device.selectedQueueIndexes.present),
  ])
  var ci = with(VkSwapchainCreateInfoKHR()) {
    $0.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
    $0.oldSwapchain = previous
    $0.surface = surface.handle
    $0.minImageCount = (device.capabilities.minImageCount + 1).clamped(
      device.capabilities.minImageCount, device.capabilities.maxImageCount)  // TODO: get this from what device reported

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
    $0.preTransform = device.capabilities.currentTransform
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

private func destroySwapchain(_ handle: VkSwapchainKHR) {

}

public struct SwapchainImage: ~Copyable {
  let imageIndex: UInt32
  let renderCompletedSemaphore: VkSemaphore
  let swapChainHandle: VkSwapchainKHR
  let presentQueue: VkQueue

  public consuming func present() {
    let imageIndex = Box(imageIndex)
    let handle = Box<VkSwapchainKHR?>(swapChainHandle)
    let renderCompletedSemaphore = Box<VkSemaphore?>(renderCompletedSemaphore)

    var info = VkPresentInfoKHR(
      sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
      pNext: nil,
      waitSemaphoreCount: 1,
      pWaitSemaphores: renderCompletedSemaphore.ptr,
      swapchainCount: 1,
      pSwapchains: handle.ptr,
      pImageIndices: imageIndex.ptr,
      pResults: nil,
    )

    vkQueuePresentKHR(presentQueue, &info).expect("Cannot present image[\(self.imageIndex)]")
    // TODO: this notify that swapchain is out of date due to resize or someshi
  }
}
