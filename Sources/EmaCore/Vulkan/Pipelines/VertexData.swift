import CVulkan

extension VertexData {
  static var bindingDescription: VkVertexInputBindingDescription {
    .init(
      binding: 0, stride: UInt32(MemoryLayout<Self>.size), inputRate: VK_VERTEX_INPUT_RATE_VERTEX)
  }

  static var attributeDescriptions: [VkVertexInputAttributeDescription] {
    [
      .init(location: 0, binding: 0, format: VK_FORMAT_R32_UINT, offset: 0),
      .init(
        location: 1, binding: 0, format: VK_FORMAT_R32G32_SFLOAT,
        offset: UInt32(MemoryLayout<Self>.offset(of: \.position)!)),
    ]
  }

}
