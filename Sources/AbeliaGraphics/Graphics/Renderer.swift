/// store node index

import Vulkan

struct SharedRendererResources {
    let context: DeviceContext
    fileprivate let pipelines: Pipelines
    let releaseQueue: ReleaseQueue = ReleaseQueue()
    let textureRegistry: TextureRegistry
    let globalDescriptorSet: DescriptorSet
}

extension SharedRendererResources {
    init(context: DeviceContext) throws(Vulkan.Result) {
        let pipelines = try Pipelines(
            format: .b8g8r8a8Srgb,
            context: context
        )
        self.context = context
        self.pipelines = pipelines
        let textureDescriptorSet = try pipelines.createTextureDescriptorSet(context)
        self.textureRegistry = TextureRegistry(
            textureDescriptorSet, releaseQueue: self.releaseQueue, context: context)
        globalDescriptorSet = try pipelines.createSamplerDescriptorSet(context)
    }

    func createFrameResources(amount: Int) throws(Vulkan.Result) -> [RendererFrameResource] {
        try (0..<amount).map { i throws(Vulkan.Result) in
            try RendererFrameResource(index: i, context: context, pipelines: pipelines)
        }
    }
}

// this should be per frame context
struct RendererFrameResource {
    let mainDescriptorSet: DescriptorSet
    let renderNodeStorage: RenderNodeStorage
    let shapeGroupStorage: ShapeGroupStorage
    let drawListStorage: DrawListStorage

    fileprivate init(index: Int, context: borrowing DeviceContext, pipelines: borrowing Pipelines)
        throws(Vulkan.Result)
    {
        let mainDescriptorSet = try pipelines.createMainDescriptorSet(context)
        let renderNodeStorage = try RenderNodeStorage(context: context)
        let shapeGroupStorage = try ShapeGroupStorage(context: context)
        let drawListStorage = try DrawListStorage(context: context)

        context.device.updateDescriptorSets(descriptorWrites: [
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 0,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: renderNodeStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 1,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: shapeGroupStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 2,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: drawListStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),

        ])

        self.mainDescriptorSet = mainDescriptorSet
        self.renderNodeStorage = renderNodeStorage
        self.shapeGroupStorage = shapeGroupStorage
        self.drawListStorage = drawListStorage
    }
}
