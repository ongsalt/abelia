@preconcurrency import CVMA
import Wayland

// TODO: resize??? -> just realloc?
class RenderTexture {
    unowned let registry: RenderTextureRegistry
    let image: VkImage
    let view: VkImageView
    let allocation: VmaAllocation
    var sampler: VkSampler
    var index: UInt32
    var size: SIMD2<UInt32>
    let actualSize: SIMD2<UInt32>

    package var hasUndefinedLayout: Bool {
        currentLayout == VK_IMAGE_LAYOUT_UNDEFINED
    }
    var currentLayout: VkImageLayout = VK_IMAGE_LAYOUT_UNDEFINED
    var currentStageMask: VkPipelineStageFlags2 = VK_PIPELINE_STAGE_2_NONE
    var currentAccessMask: VkAccessFlags2 = VK_ACCESS_2_NONE

    var descriptorImageInfo: VkDescriptorImageInfo {
        VkDescriptorImageInfo(
            sampler: sampler,
            imageView: view,
            imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL  // fucking lieeee
        )
    }

    init(
        registry: RenderTextureRegistry,
        size: SIMD2<UInt32>,
        actualSize: SIMD2<UInt32>? = nil,
        index: UInt32,
        edgeSampling: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
        usages: VkImageUsageFlags = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue
            | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue,
        samples: VkSampleCountFlagBits = VK_SAMPLE_COUNT_4_BIT,
        format: VkFormat? = nil,
        unnormalizedCoordinates: VkBool32 = false
    ) {
        self.registry = registry
        self.index = index
        self.size = size
        self.actualSize = actualSize ?? size
        let vulkan = registry.vulkan
        var image = VkImage(bitPattern: 0)
        let format = format ?? vulkan.swapChain.surfaceFormat.format

        let imageCreateInfo = Box(VkImageCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
            $0.imageType = VK_IMAGE_TYPE_2D
            $0.format = format  // TODO: why this
            $0.extent = VkExtent3D(width: size.x, height: size.y, depth: 1)
            $0.mipLevels = 1
            $0.arrayLayers = 1
            $0.samples = samples
            $0.tiling = VK_IMAGE_TILING_OPTIMAL
            $0.usage = usages
            $0.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        }

        var bufferAllocCI = VmaAllocationCreateInfo(
            flags: VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT.rawValue,
            usage: VMA_MEMORY_USAGE_AUTO,
            requiredFlags: 0,
            preferredFlags: 0,
            memoryTypeBits: 0,
            pool: nil,
            pUserData: nil,
            priority: 0
        )

        var allocation = VmaAllocation(bitPattern: 0)
        vmaCreateImage(
            vulkan.allocator,
            imageCreateInfo.ptr,
            &bufferAllocCI,
            &image,
            &allocation,
            nil
        ).expect("Cannot create image")
        self.allocation = allocation!
        self.image = image!

        let imageViewCI = Box(VkImageViewCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
            $0.image = image
            $0.viewType = VK_IMAGE_VIEW_TYPE_2D
            $0.format = format
            $0.subresourceRange = VkImageSubresourceRange(
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1
            )
        }
        var imageView = VkImageView(bitPattern: 0)
        vkCreateImageView(vulkan.device, imageViewCI.ptr, nil, &imageView)
            .expect("Cannot create image view")
        self.view = imageView!

        var ci = with(VkSamplerCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
            $0.magFilter = VK_FILTER_LINEAR
            $0.minFilter = VK_FILTER_LINEAR
            $0.addressModeU = edgeSampling
            $0.addressModeV = edgeSampling
            $0.addressModeW = edgeSampling
            // $0.unnormalizedCoordinates = unnormalizedCoordinates
            // $0.anisotropyEnable = false // no use in 2d??
        }
        var sampler = VkSampler(bitPattern: 0)
        vkCreateSampler(
            vulkan.device,
            &ci,
            nil,
            &sampler
        ).expect("Cannot create sampler")
        self.sampler = sampler!

    }

    func transitionCommand(
        to targetLayout: VkImageLayout,
        stageMask: VkPipelineStageFlags2 = 0,
        accessMask: VkAccessFlags2,
        cb: VkCommandBuffer
    ) {
        let barrier = Box(
            barrier(
                to: targetLayout,
                stageMask: stageMask,
                accessMask: accessMask
            )
        )

        let barrierPresentDependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
            $0.pImageMemoryBarriers = barrier.readonly
        }

        vkCmdPipelineBarrier2(cb, barrierPresentDependencyInfo.ptr)
    }

    func barrier(
        to targetLayout: VkImageLayout,
        stageMask: VkPipelineStageFlags2,
        accessMask: VkAccessFlags2,
    ) -> VkImageMemoryBarrier2 {
        let barrier = with(VkImageMemoryBarrier2()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2
            $0.srcStageMask = currentStageMask
            $0.srcAccessMask = currentAccessMask
            $0.dstStageMask = stageMask
            $0.dstAccessMask = accessMask
            $0.oldLayout = currentLayout
            $0.newLayout = targetLayout
            $0.image = self.image
            $0.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
            $0.subresourceRange.levelCount = 1
            $0.subresourceRange.layerCount = 1
            $0.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            $0.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
        }

        self.currentLayout = targetLayout
        self.currentStageMask = stageMask
        self.currentAccessMask = accessMask

        return barrier
    }

    // TODO: cleanup this on deinit?
}

extension RenderTexture: Equatable {
    static func == (lhs: RenderTexture, rhs: RenderTexture) -> Bool {
        lhs.image == rhs.image
    }
}
