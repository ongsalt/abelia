@preconcurrency import CVMA
import Wayland

class RenderTexture {
    unowned let registry: RenderTextureRegistry
    let image: VkImage
    let view: VkImageView
    let allocation: VmaAllocation
    let sampler: VkSampler
    let layout: VkImageLayout
    var index: UInt32

    var descriptorImageInfo: VkDescriptorImageInfo {
        VkDescriptorImageInfo(
            sampler: sampler,
            imageView: view,
            imageLayout: layout
        )
    }

    init(
        registry: RenderTextureRegistry, image: VkImage, view: VkImageView,
        allocation: VmaAllocation, sampler: VkSampler, layout: VkImageLayout, index: UInt32
    ) {
        self.registry = registry
        self.image = image
        self.view = view
        self.allocation = allocation
        self.sampler = sampler
        self.layout = layout
        self.index = index
    }

    func transition(
        from oldLayout: VkImageLayout,
        to targetLayout: VkImageLayout,
        waitFor srcStageMask: VkPipelineStageFlags2,
        blocking dstStageMask: VkPipelineStageFlags2,
        srcAccessMask: VkAccessFlags2,
        dstAccessMask: VkAccessFlags2,
    ) {
        let barrier = Box(VkImageMemoryBarrier2()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
            $0.srcStageMask = srcStageMask
            $0.srcAccessMask = srcAccessMask
            $0.dstStageMask = dstStageMask
            $0.dstAccessMask = dstAccessMask
            $0.oldLayout = oldLayout
            $0.newLayout = targetLayout
            $0.image = self.image
            $0.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
            $0.subresourceRange.levelCount = 1
            $0.subresourceRange.layerCount = 1
            $0.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            $0.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
        }

        let barrierPresentDependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
            $0.pImageMemoryBarriers = barrier.readonly
        }

        registry.vulkan.command { cb in
            vkCmdPipelineBarrier2(cb, barrierPresentDependencyInfo.ptr)
        }
    }
}
