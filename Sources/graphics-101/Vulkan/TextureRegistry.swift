@preconcurrency import CVMA

class TextureRegistry {

    func createTexture() {

    }
}

func createBindingLayout() {
    let bindings = VkDescriptorSetLayoutBinding(
        binding: 10,
        descriptorType: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        descriptorCount: 1024,
        stageFlags: VK_SHADER_STAGE_FRAGMENT_BIT.rawValue,
        pImmutableSamplers: nil
    )
}
