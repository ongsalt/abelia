@preconcurrency import CVMA
import Foundation
import Wayland

struct BindingInfo {
    let bindingDescriptions: [VkVertexInputBindingDescription]
    let attributeDescriptions: [VkVertexInputAttributeDescription]
    let descriptorSetLayouts: [VkDescriptorSetLayout] = []

    static var none: BindingInfo {
        BindingInfo(bindingDescriptions: [], attributeDescriptions: [])
    }
}
