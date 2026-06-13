import CShim
import Vulkan

// 1 to 1 with shader data (in term of information not layout)
public class RenderNode: Identifiable {
    public var brush: Brush = .solid(.transparent) {
        didSet { dirty = true }
    }

    public var shape: any ShapeProtocol = Shape.rect(width: 0, height: 0) {
        didSet { dirty = true }
    }

    // border
    // shadow
    public var affine: Affine = .identity {
        didSet { dirty = true }
    }

    public var offset: SIMD3<Float> = .zero {
        didSet { dirty = true }
    }

    public var scale: SIMD2<Float> = .one {
        didSet { dirty = true }
    }

    private(set) var dirty: Bool = false
    /// combine with offset and scale
    var nodeTotalAffine: Affine {
        Affine
            .identity
            .scaled(x: scale.x, y: scale.y)
            .translated(x: offset.x, y: offset.y, z: offset.z)
            .multiplied(by: affine)
    }

    public init() {

    }
}
