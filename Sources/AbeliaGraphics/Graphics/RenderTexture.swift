import Vulkan

class RenderTexture: Identifiable {
    private(set) unowned var registry: RenderTextureRegistry
    private(set) var index: Int
    /// dimension of the image
    fileprivate(set) var size: SIMD2<UInt32> = .zero
    /// actual dimension in memory, capacity >= size
    fileprivate(set) var capacity: SIMD2<UInt32> = .zero

    fileprivate var image: Image

    var lastContentHash: Int?

    init(_ registry: RenderTextureRegistry, index: Int, image: Image) {
        self.registry = registry
        self.image = image
        self.index = index
    }
}
// we also need to handle masking texture
// TODO: texture atlas for static texture, for now just use this class for everything
// - need to group draw call by atlas -> in case we are doing backdrop effect, its all sample from same texture anyway
class RenderTextureRegistry {
    private let device: Device
    // let texturesDescriptorPool: DescriptorPool
    // let texturesDescriptorSet: DescriptorSet

    private var pool: [RenderTexture] = []
    private var inUseTextures: [ObjectIdentifier: RenderTexture] = [:]

    init(device: Device) {
        self.device = device

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
