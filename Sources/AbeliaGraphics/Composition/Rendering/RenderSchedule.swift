import CShim
import Vulkan

nonisolated(unsafe) let subresourceRange = ImageSubresourceRange(
    aspectMask: .color, baseMipLevel: 0, levelCount: 1,
    baseArrayLayer: 0, layerCount: 1
)

// // just for convenience
// struct FrameRenderer {
//     let resource: RendererFrameResource
//     let registry: TextureRegistry
//     let textureCache: TextureCache
//     let commandBuffer: CommandBuffer
//     let pipelines: Pipelines
//     let globalDescriptorSet: DescriptorSet


// }

