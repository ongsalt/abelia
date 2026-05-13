@preconcurrency import CVulkan
import Pointer

class Texture {
  let device: GraphicsDevice
  let handle: VkImage
  var size: Size<UInt32> = .zero
  let usages: TextureUsages

  let allocation: VmaAllocation
  // var size: Size<UInt32> = .zero
  private var currentLayout: TextureLayout = .undefined
  private var currentQueueIndex: UInt32 = 0

  init(device: GraphicsDevice, size: Size<UInt32>, usages: TextureUsages, queueIndex: UInt32) {
    self.device = device
    self.size = size
    self.usages = usages
    self.currentQueueIndex = queueIndex

    var ci = with(VkImageCreateInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
      $0.imageType = VK_IMAGE_TYPE_2D
      $0.extent.depth = 1
      $0.extent.width = size.x
      $0.extent.height = size.y
      $0.format = VK_FORMAT_R8G8B8A8_UNORM
      $0.mipLevels = 1
      $0.arrayLayers = 1

      $0.usage = VK_IMAGE_USAGE_SAMPLED_BIT.u32
      if usages.contains(.canvas) {
        $0.usage |= VK_IMAGE_USAGE_TRANSFER_SRC_BIT.u32
      }
      if usages.contains(.layer) {
        $0.usage |= VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.u32
      }

      $0.samples = VK_SAMPLE_COUNT_4_BIT
    }
    var vmaCi = VmaAllocationCreateInfo(
      flags: 0,
      usage: VMA_MEMORY_USAGE_GPU_ONLY,
      requiredFlags: 0,
      preferredFlags: 0,
      memoryTypeBits: 0,
      pool: nil,
      pUserData: nil,
      priority: 1.0
    )

    var image: VkImage?
    var allocation: VmaAllocation?
    vmaCreateImage(device.vma, &ci, &vmaCi, &image, &allocation, nil).unwrap()

    self.allocation = allocation!
    self.handle = image!
  }

  func transition(
    to layout: TextureLayout, queueFamily: UInt32? = nil, on commandBuffer: VkCommandBuffer
  ) {
    let barrier = Box(VkImageMemoryBarrier2()) {
      $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
      $0.image = self.handle
      $0.subresourceRange = .init(
        aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.u32,
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1
      )

      $0.srcStageMask = self.currentLayout.stageMask
      $0.srcAccessMask = self.currentLayout.accessMask
      $0.oldLayout = self.currentLayout.vkLayout

      $0.dstStageMask = layout.stageMask
      $0.dstAccessMask = layout.accessMask
      $0.newLayout = layout.vkLayout
    }

    var dependencyInfo = with(VkDependencyInfo()) {
      $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
      $0.imageMemoryBarrierCount = 1
      $0.pImageMemoryBarriers = barrier.ptr
    }

    vkCmdPipelineBarrier2(commandBuffer, &dependencyInfo)
  }

  func destroy() {
    vmaDestroyImage(device.vma, self.handle, self.allocation)
  }
  // deinit {
  // }
}

struct TextureUsages: OptionSet {
  let rawValue: Int

  static let layer = TextureUsages(rawValue: 1 << 0)
  static let `static` = TextureUsages(rawValue: 2 << 0)
  // static let swapchain = TextureUsages(rawValue: 3 << 0)
  // cpu drawn
  static let canvas = TextureUsages(rawValue: 4 << 0)
}

enum TextureLayout {
  case undefined
  case renderAttachment
  case sampling
  case copyTarget

  var accessMask: VkAccessFlags2 {
    switch self {
    case .sampling:
      VK_ACCESS_2_SHADER_READ_BIT
    case .renderAttachment:
      VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT
    case .copyTarget:
      VK_ACCESS_2_TRANSFER_WRITE_BIT
    case .undefined:
      VK_ACCESS_2_NONE
    }

  }

  var stageMask: VkPipelineStageFlags2 {
    switch self {
    case .sampling:
      VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT
    case .renderAttachment:
      VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT
    case .undefined, .copyTarget:
      VK_PIPELINE_STAGE_2_NONE
    }
  }

  var vkLayout: VkImageLayout {
    switch self {
    case .sampling:
      VK_IMAGE_LAYOUT_READ_ONLY_OPTIMAL
    case .renderAttachment:
      VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
    case .copyTarget:
      VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
    case .undefined:
      VK_IMAGE_LAYOUT_UNDEFINED
    }
  }

}
