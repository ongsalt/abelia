import CShim
import Vulkan

public struct ImageAndView {
    public var image: Image
    public var view: ImageView

    public init(image: Image, view: ImageView) {
        self.image = image
        self.view = view
    }
}

public protocol RenderTextureProtocol {
    var index: Int { get }
    var image: Image { get }
    var view: ImageView { get }
    var size: SIMD2<UInt32> { get }
    var capacity: SIMD2<UInt32> { get }
}

public class RenderTexture: RenderTextureProtocol {
    public var image: Vulkan.Image { vmaImage.image }
    public var view: Vulkan.ImageView { vmaImage.view }

    private let vmaImage: VmaImage
    private(set) unowned var registry: TextureRegistry
    private(set) public var index: Int

    /// actual dimension in memory, capacity >= size
    public var capacity: SIMD2<UInt32> { vmaImage.size }
    /// dimension of the image
    fileprivate(set) public var size: SIMD2<UInt32>
    // this shit must be combine with brush crop/ninepatch from the cpu side

    var currentLayout: ImageLayout = .undefined

    init(_ registry: TextureRegistry, vmaImage: VmaImage, index: Int) {
        self.registry = registry
        self.index = index
        self.vmaImage = vmaImage
        self.size = vmaImage.size
    }

    func canResize(to size: SIMD2<UInt32>) -> Bool {
        return size.x <= self.size.x && size.y <= self.size.y
    }

    func recycle() {
        registry.recycle(self)
    }

    func destroy() {
        vmaImage.destroy()
    }
}

// we also need to handle masking texture
class TextureRegistry {
    let context: DeviceContext
    let releaseQueue: ReleaseQueue

    let textureDescriptorSet: DescriptorSet

    private var textures: [RenderTexture] = []
    // TODO: optimize for query by size some how
    var availableTextures: [RenderTexture] = []
    let maxTextureCount: UInt32 = 512 * 1024
    //
    let format: Format

    // its either r8g8b8a8Unorm or 16 bit float
    init(
        _ textureDescriptorSet: DescriptorSet,
        releaseQueue: ReleaseQueue,
        context: DeviceContext,
        format: Format = .b8g8r8a8Srgb
    ) {
        self.context = context
        self.textureDescriptorSet = textureDescriptorSet
        self.format = format
        self.releaseQueue = releaseQueue
    }

    func getRenderTexture(size: SIMD2<UInt32>)
        throws(Vulkan.Result) -> RenderTexture
    {
        var texture = availableTextures.first { t in
            t.capacity.x >= size.x && t.capacity.y >= size.y
        }

        if let texture {
            texture.size = size
        } else {
            texture = try createRenderTexture(size: size)
        }

        return texture!
    }

    func createRenderTexture(
        size: SIMD2<UInt32>, format: Format? = nil,
        usages: ImageUsageFlags = [.sampled, .colorAttachment]
    ) throws(Vulkan.Result) -> RenderTexture {
        let image = try VmaImage(
            size: size, format: format ?? self.format, usages: usages, context: self.context)

        let index = textures.count
        let texture = RenderTexture(self, vmaImage: image, index: index)
        textures.append(texture)

        context.device.updateDescriptorSets(descriptorWrites: [
            WriteDescriptorSet(
                dstSet: self.textureDescriptorSet, dstBinding: 0, dstArrayElement: UInt32(index),
                descriptorCount: 1, descriptorType: .sampledImage,
                imageInfo: [
                    DescriptorImageInfo(
                        imageView: texture.view,
                        imageLayout: .shaderReadOnlyOptimal
                    )
                ],
                bufferInfo: [],
                texelBufferView: []
            )
        ])

        return texture
    }

    func recycle(_ texture: consuming RenderTexture) {
        availableTextures.append(texture)
    }
}

// if not found then resolve new one, if outdate -> recycle
class TextureCache {
    typealias LayerID = _BaseLayer.ID
    var cache: [LayerID: CompositeGroupTextures] = [:]

    subscript(_ key: LayerID) -> CompositeGroupTextures? {
        get {
            cache[key]
        }

        set {
            cache[key] = newValue
        }
    }

}

struct CompositeGroupTextures {
    var main: RenderTexture
    var alternate: RenderTexture?

    mutating func swap() {
        if let a = alternate {
            self.alternate = main
            main = a
        }
    }

    mutating func swapWithNew(_ newValue: RenderTexture) {
        self.alternate = self.main
        self.main = newValue
    }
}
