@preconcurrency import CVMA
import Foundation
import Wayland

class RenderTextureRegistry {
    let vulkan: VulkanState
    let descriptorPool: VkDescriptorPool
    let descriptorSetLayout: VkDescriptorSetLayout
    let descriptorSet: VkDescriptorSet
    private var textures: [RenderTexture] = []
    private let maxSize: UInt32

    init(vulkan: VulkanState) {
        self.maxSize = 128
        self.vulkan = vulkan
        self.descriptorPool = Self.createDescriptorPool(vulkan: vulkan, maxSize: maxSize)
        self.descriptorSetLayout = Self.createDescriptorSetLayout(vulkan: vulkan, maxSize: maxSize)
        self.descriptorSet = Self.createDescriptorSet(
            vulkan: vulkan,
            descriptorPool: descriptorPool,
            descriptorSetLayout: descriptorSetLayout,
            maxSize: maxSize
        )

    }

    func newRenderTarget(
        size: SIMD2<UInt32>,
        edgeSampling: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT
    ) -> RenderTexture {
        var image = VkImage(bitPattern: 0)
        let format = vulkan.swapChain.surfaceFormat.format

        let imageCreateInfo = Box(VkImageCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
            $0.imageType = VK_IMAGE_TYPE_2D
            $0.format = format  // TODO: why this
            $0.extent = VkExtent3D(width: size.x, height: size.y, depth: 1)
            $0.mipLevels = 1
            $0.arrayLayers = 1
            $0.samples = VK_SAMPLE_COUNT_4_BIT
            $0.tiling = VK_IMAGE_TILING_OPTIMAL
            $0.usage =
                VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue
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

        var ci = with(VkSamplerCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
            $0.magFilter = VK_FILTER_LINEAR
            $0.minFilter = VK_FILTER_LINEAR
            $0.addressModeU = edgeSampling
            $0.addressModeV = edgeSampling
            $0.addressModeW = edgeSampling
            // $0.anisotropyEnable = false // no use in 2d??
        }
        var sampler = VkSampler(bitPattern: 0)
        vkCreateSampler(
            vulkan.device,
            &ci,
            nil,
            &sampler
        ).expect("Cannot create sampler")

        // TODO: get index
        let texture = RenderTexture(
            registry: self,
            image: image!,
            view: imageView!,
            allocation: allocation!,
            sampler: sampler!,
            layout: VK_IMAGE_LAYOUT_UNDEFINED,
            index: numericCast(textures.count)
        )
        self.textures.append(texture)

        self.updateDescriptorSet()

        texture.transition(
            from: VK_IMAGE_LAYOUT_UNDEFINED,
            to: VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL,
            waitFor: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            blocking: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            srcAccessMask: 0,
            dstAccessMask: VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT
                | VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT
        )

        return texture
    }

    // once per frame
    private func updateDescriptorSet() {
        for (index, t) in textures.enumerated() {
            t.index = UInt32(index)
        }
        // now add actual data to it
        // TODO: we need to update this. a lot
        let imageInfo = Pin(
            textures.map {
                var info = $0.descriptorImageInfo
                info.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL  // lieeee
                return info
            })
        var writeDescSet = with(VkWriteDescriptorSet()) {
            $0.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
            $0.dstSet = descriptorSet
            $0.dstBinding = 0
            $0.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
            $0.descriptorCount = UInt32(textures.count)
            $0.pImageInfo = imageInfo.readonly
        }
        // Log.debug(.vulkan, "writeDescSet: \(writeDescSet)")
        // VkDescriptorImageInfo(sampler: VkSampler!, imageView: VkImageView!, imageLayout: VK_IMAGE_LAYOUT_VIDEO_ENCODE_DPB_KHR)
        vkUpdateDescriptorSets(vulkan.device, 1, &writeDescSet, 0, nil)
    }

    static func createDescriptorSetLayout(vulkan: VulkanState, maxSize: UInt32 = 128)
        -> VkDescriptorSetLayout
    {
        let layoutBinding = Box(VkDescriptorSetLayoutBinding()) {
            $0.binding = 0
            $0.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
            $0.descriptorCount = maxSize  // how tf would i know,
            $0.stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT.rawValue
        }
        let flags = Box(
            VkDescriptorBindingFlags(
                VK_DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT.rawValue
                    // | VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT.rawValue
                    // | VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT.rawValue
            )
        )
        let bindingFlags = Box(
            VkDescriptorSetLayoutBindingFlagsCreateInfo(
                sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
                pNext: nil,
                bindingCount: 1,
                pBindingFlags: flags.ptr
            ))
        var descriptorSetLayoutCI = with(VkDescriptorSetLayoutCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
            $0.bindingCount = 1
            $0.pBindings = layoutBinding.readonly
            $0.pNext = bindingFlags.raw
        }

        let descriptorSetLayout = Box(VkDescriptorSetLayout(bitPattern: 0)) {
            vkCreateDescriptorSetLayout(vulkan.device, &descriptorSetLayoutCI, nil, &$0).unwrap()
        }

        return descriptorSetLayout.pointee!
    }

    static func createDescriptorSet(
        vulkan: VulkanState,
        descriptorPool: VkDescriptorPool,
        descriptorSetLayout: VkDescriptorSetLayout,
        maxSize: UInt32 = 128
    ) -> VkDescriptorSet {
        // Allocate the fucking descriptor

        let variableDescCount = Box(maxSize)
        let variableDescCountAI = Box(
            VkDescriptorSetVariableDescriptorCountAllocateInfo(
                sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_VARIABLE_DESCRIPTOR_COUNT_ALLOCATE_INFO,
                pNext: nil,
                descriptorSetCount: 1,
                pDescriptorCounts: variableDescCount.ptr
            ))

        let descriptorSetLayout: Box<VkDescriptorSetLayout?> = Box(descriptorSetLayout)
        var descriptorSetAllocateInfo = VkDescriptorSetAllocateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            pNext: variableDescCountAI.ptr,
            descriptorPool: descriptorPool,
            descriptorSetCount: 1,
            pSetLayouts: descriptorSetLayout.readonly
        )

        var descriptorSet = VkDescriptorSet(bitPattern: 0)
        vkAllocateDescriptorSets(vulkan.device, &descriptorSetAllocateInfo, &descriptorSet).expect(
            "Cannot create descriptor set")

        return descriptorSet!
    }

    static func createDescriptorPool(vulkan: VulkanState, maxSize: UInt32 = 128) -> VkDescriptorPool
    {
        let poolSize = Box(
            VkDescriptorPoolSize(
                type: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                descriptorCount: maxSize
            ))

        let descPoolCI = Box(VkDescriptorPoolCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
            $0.maxSets = 1
            $0.poolSizeCount = 1
            $0.pPoolSizes = poolSize.readonly
        }

        var descriptorPool = VkDescriptorPool(bitPattern: 0)
        vkCreateDescriptorPool(vulkan.device, descPoolCI.ptr, nil, &descriptorPool).expect(
            "Cannot create descriptor pool")

        return descriptorPool!
    }
}
