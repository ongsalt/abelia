import Vulkan

class RenderTexture: Identifiable {
    private(set) unowned var registry: TextureRegistry
    private(set) var index: Int
    /// dimension of the image
    fileprivate(set) var size: SIMD2<UInt32> = .zero
    /// actual dimension in memory, capacity >= size
    fileprivate(set) var capacity: SIMD2<UInt32> = .zero

    fileprivate var image: Image

    var lastContentHash: Int?

    init(_ registry: TextureRegistry, index: Int, image: Image) {
        self.registry = registry
        self.image = image
        self.index = index
    }
}

// we also need to handle masking texture
// TODO: texture atlas for static texture, for now just use this class for everything
// - need to group draw call by atlas -> in case we are doing backdrop effect, its all sample from same texture anyway
class TextureRegistry {
    private let context: DeviceContext
    let texturesDescriptorPool: DescriptorPool
    let texturesDescriptorSet: DescriptorSet

    private var pool: [Int:RenderTexture] = [:]
    private var inUseTextures: [ObjectIdentifier: RenderTexture] = [:]
    let maxTextureCount: UInt32 = 65536

    init(context: DeviceContext) {
        self.context = context
    }

    static func createResources(context: DeviceContext) throws -> (DescriptorPool, DescriptorSet,  maxTextureCount: UInt32) {
        // context.physicalDevice.getProperties2()
        // TODO: query maxDescriptorSetUpdateAfterBindSampledImages
        let maxTextureCount: UInt32 = 1024 * 64 // just to be safe 
        let pool = try context.device.createDescriptorPool(
            .init(
                flags: .updateAfterBind, 
                maxSets: 1, 
                poolSizes: [
                    .init(type: .sampledImage, descriptorCount: maxTextureCount)
                ]
            )
        )
        // let descriptorSets = try device.allocateDescriptorSets(
        //     .init(
        //         descriptorPool: descriptorPool,
        //         setLayouts: [mainDescriptorSetLayout]
        //     )
        // )

    }

    func getOrCreateRenderTexture(size: SIMD2<UInt32>) -> RenderTexture {
        fatalError("unimplemented")
        // device.createImage(
        //     .init(
        //         imageType: .type2d, format: .a8b8g8r8UintPack32,
        //         extent: .init(width: 10, height: 10, depth: 1),
        //         mipLevels: 1,
        //         arrayLayers: 0, samples: .type4, tiling: .optimal,
        //         usage: .colorAttachment, sharingMode: .exclusive, initialLayout: .undefined)
        // )
    }

    private func createRenderTexture(size: SIMD2<UInt32>) -> RenderTexture {
        fatalError("unimplemented")
        // device.createImage(
        //     .init(
        //         imageType: .type2d, format: .a8b8g8r8UintPack32,
        //         extent: .init(width: 10, height: 10, depth: 1),
        //         mipLevels: 1,
        //         arrayLayers: 0, samples: .type4, tiling: .optimal,
        //         usage: .colorAttachment, sharingMode: .exclusive, initialLayout: .undefined)
        // )
    }

    // func get(size: SIMD2<UInt32>) -> RenderTexture {

    // }

    func recycle(_ texture: RenderTexture) {

    }
}
