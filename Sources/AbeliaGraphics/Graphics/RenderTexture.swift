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

// unused
public class StaticTexture: RenderTextureProtocol {
    public let index: Int

    public var image: Vulkan.Image {
        vmaImage.image
    }
    public var view: Vulkan.ImageView {
        vmaImage.view
    }

    public var size: SIMD2<UInt32> {
        vmaImage.size
    }

    public var capacity: SIMD2<UInt32> {
        vmaImage.size
    }

    private let vmaImage: VmaImage

    init(_ vmaImage: VmaImage, index: Int) {
        self.vmaImage = vmaImage
        self.index = index
    }
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
}

// we also need to handle masking texture
// TODO: texture atlas for static texture, for now just use this class for everything
// - need to group draw call by atlas -> in case we are doing backdrop effect, its all sample from same texture anyway
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
        format: Format = .r8g8b8a8Unorm
    ) {
        self.context = context
        self.textureDescriptorSet = textureDescriptorSet
        self.format = format
        self.releaseQueue = releaseQueue
    }

    // if unchange for too long -> recreate with exact: true
    // if unused for too long -> delete
    func getRenderTexture(size: SIMD2<UInt32>, animatingSize: Bool = false)
        throws(Vulkan.Result) -> RenderTexture
    {
        let w = Float(size.x) * (animatingSize ? 1.35 : 1)
        let h = Float(size.y) * (animatingSize ? 1.35 : 1)
        let area = UInt32(w * h)

        var texture = availableTextures.first { t in
            if t.size.x * t.size.y >= area {
                return false
            }
            return t.size.x >= size.x && t.size.y >= size.y
        }

        // if its too large, allocate new
        //
        if texture == nil || texture!.size.x * texture!.size.y > area * 2 {
            texture = try createRenderTexture(
                size: SIMD2(
                    UInt32(w.rounded(.up)),
                    UInt32(h.rounded(.up))
                )
            )
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

    func recycle(_ texture: RenderTexture) {

    }
}

class VmaImage {
    let image: Image
    let view: ImageView
    private let allocation: VmaAllocation
    private let allocator: VmaAllocator
    let size: SIMD2<UInt32>

    init(
        _ image: Image, _ view: ImageView,
        _ allocation: VmaAllocation,
        _ allocator: VmaAllocator,
        size: SIMD2<UInt32>
    ) {
        self.image = image
        self.view = view
        self.allocation = allocation
        self.allocator = allocator
        self.size = size
    }

    init(
        size: SIMD2<UInt32>,
        format: Format,
        usages: ImageUsageFlags = [.sampled, .colorAttachment],
        context: borrowing DeviceContext
    ) throws(Vulkan.Result) {
        let device = context.device
        var vkImage: VkImage?
        var vmaAlloc: VmaAllocation?
        var vmaCi = VmaAllocationCreateInfo()
        vmaCi.usage = VMA_MEMORY_USAGE_AUTO
        let extent = Extent3D(width: size.x, height: size.y, depth: 1)
        try checkResult(
            ImageCreateInfo(
                imageType: .type2d,
                format: format,
                extent: extent,
                mipLevels: 1,
                arrayLayers: 1,
                samples: .type1,
                tiling: .optimal,
                usage: usages,
                sharingMode: .exclusive,
                initialLayout: .undefined
            ).withCStruct {
                vmaCreateImage(context.allocator, $0, &vmaCi, &vkImage, &vmaAlloc, nil)
            }
        )

        self.image = Image(handle: vkImage!, device: device)
        self.view = try device.createImageView(
            .init(
                image: image,
                viewType: .type2d,
                format: format,
                components: .init(r: .r, g: .g, b: .b, a: .a),
                subresourceRange: .init(
                    aspectMask: .color, baseMipLevel: 0, levelCount: 1,
                    baseArrayLayer: 0, layerCount: 1)
            )
        )

        self.allocation = vmaAlloc!
        self.size = size
        self.allocator = context.allocator
    }

    func destroy() {
        view.destroy()
        vmaDestroyImage(allocator, image.handle, allocation)
    }
}
