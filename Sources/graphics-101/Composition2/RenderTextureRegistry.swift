@preconcurrency import CVMA
import Foundation
import Wayland

class RenderTextureRegistry {
    let vulkan: VulkanState
    let descriptorPool: VkDescriptorPool
    let descriptorSetLayout: VkDescriptorSetLayout
    let descriptorSet: VkDescriptorSet
    private(set) var textures: [RenderTexture] = []
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
        actualSize: SIMD2<UInt32>? = nil,
        edgeSampling: VkSamplerAddressMode = VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT
    ) -> RenderTexture {
        // TODO: get index
        let texture = RenderTexture(
            registry: self,
            size: size,
            actualSize: actualSize ?? size,
            index: numericCast(textures.count),
            edgeSampling: edgeSampling
        )
        self.textures.append(texture)
        self.updateDescriptorSet()
        //     await texture.transition(
        //     from: VK_IMAGE_LAYOUT_UNDEFINED,
        //     to: VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL,
        //     waitFor: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
        //     blocking: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
        //     srcAccessMask: 0,
        //     dstAccessMask: VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT
        //         | VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT
        // )
        return texture
    }

    // pango shit
    func createStaticTexture(
        from buffer: UnsafeMutableBufferPointer<UInt8>, 
        size: SIMD2<UInt32>, 
        format: VkFormat,
        
    )
        async -> RenderTexture
    {
        let texture = RenderTexture(
            registry: self,
            size: size,
            index: numericCast(textures.count),
            edgeSampling: VK_SAMPLER_ADDRESS_MODE_REPEAT,
            // edgeSampling: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            usages: VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue,
            samples: VK_SAMPLE_COUNT_1_BIT,
            format: format,
        )
        self.textures.append(texture)
        self.updateDescriptorSet()

        let stagingBuffer = RawGPUBuffer(
            allocator: vulkan.allocator,
            device: vulkan.device,
            size: buffer.count * MemoryLayout<UInt8>.stride,
            usages: VK_BUFFER_USAGE_TRANSFER_SRC_BIT  // fuck, TODO: buffer usage v2
        )
        _ = stagingBuffer.write(UnsafeBufferPointer(buffer))

        await vulkan.runCommands { cb in
            texture.transitionCommand(
                from: VK_IMAGE_LAYOUT_UNDEFINED,
                to: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                dstStageMask: VK_PIPELINE_STAGE_2_COPY_BIT,
                srcAccessMask: 0,
                dstAccessMask: VK_ACCESS_2_TRANSFER_WRITE_BIT,
                cb: cb
            )

            var region = VkBufferImageCopy()
            region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
            region.imageSubresource.layerCount = 1
            region.imageExtent = size.extent3d  // Set to your image dimensions

            vkCmdCopyBufferToImage(
                cb, stagingBuffer.buffer, texture.image,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region)

            texture.transitionCommand(
                from: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                to: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                srcStageMask: VK_PIPELINE_STAGE_2_COPY_BIT,
                dstStageMask: VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT,
                srcAccessMask: VK_ACCESS_2_TRANSFER_WRITE_BIT,
                dstAccessMask: VK_ACCESS_2_SHADER_SAMPLED_READ_BIT,
                cb: cb
            )

        }
        // Log.debug(.vulkan, "stagingBuffer.buffer: \(stagingBuffer.buffer)")

        return texture
    }

    func destroy(_ texture: consuming RenderTexture) {
        textures.removeAll(where: { $0 == texture })
    }

    // once per frame
    private func updateDescriptorSet() {
        for (index, t) in textures.enumerated() {
            t.index = UInt32(index)
        }

        let imageInfo = Pin(
            textures.map(\.descriptorImageInfo)
        )
        var writeDescSet = with(VkWriteDescriptorSet()) {
            $0.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
            $0.dstSet = descriptorSet
            $0.dstBinding = 0
            $0.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
            $0.descriptorCount = UInt32(textures.count)
            $0.pImageInfo = imageInfo.readonly
        }

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
