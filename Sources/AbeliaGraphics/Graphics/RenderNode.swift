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

    public var borderWidth: Float = 0 {
        didSet { dirty = true }
    }

    public var borderBrush: Brush = .solid(.transparent) {
        didSet { dirty = true }
    }

    public var shadowOffset: SIMD2<Float> = .zero {
        didSet { dirty = true }
    }

    public var shadowBlur: Float = 0 {
        didSet { dirty = true }
    }

    public var shadowSpread: Float = 0 {
        didSet { dirty = true }
    }

    public var shadowColor: Color = .black {
        didSet { dirty = true }
    }

    public var shadowOpacity: Float = 0 {
        didSet { dirty = true }
    }

    // TODO: backfaceVisibility
    public var affine: Affine = .identity {
        didSet { dirty = true }
    }

    public var offset: SIMD3<Float> = .zero {
        didSet { dirty = true }
    }

    public var scale: SIMD2<Float> = .one {
        didSet { dirty = true }
    }

    public var rotation: Angle = .radians(0) {
        didSet { dirty = true }
    }

    public var rotationAxis: SIMD3<Float> = [0, 0, 1] {
        didSet { dirty = true }
    }

    /// pivot point for scale and rotation, in local space — behaves like CSS transform-origin
    public var transformOrigin: SIMD2<Float> = .zero {
        didSet { dirty = true }
    }

    var hidden: Bool = false

    private(set) var dirty: Bool = false

    var nodeTotalAffine: Affine {
        let ox = transformOrigin.x
        let oy = transformOrigin.y
        return Affine.identity
            .translated(x: offset.x, y: offset.y, z: offset.z)
            .translated(x: ox, y: oy)
            .multiplied(by: affine)
            .rotated(rotation, axis: rotationAxis)
            .scaled(x: scale.x, y: scale.y)
            .translated(x: -ox, y: -oy)
    }

    public init() {}

    public convenience init(
        shape: any ShapeProtocol,
        brush: Brush = .solid(.transparent),
        borderWidth: Float = 0,
        borderBrush: Brush = .solid(.transparent),
        shadowOffset: SIMD2<Float> = .zero,
        shadowBlur: Float = 0,
        shadowSpread: Float = 0,
        shadowColor: Color = .black,
        shadowOpacity: Float = 0,
        offset: SIMD3<Float> = .zero,
        scale: SIMD2<Float> = .one,
        rotation: Angle = .radians(0),
        rotationAxis: SIMD3<Float> = [0, 0, 1],
        transformOrigin: SIMD2<Float> = .zero,
        affine: Affine = .identity
    ) {
        self.init()
        self.shape = shape
        self.brush = brush
        self.borderWidth = borderWidth
        self.borderBrush = borderBrush
        self.shadowOffset = shadowOffset
        self.shadowBlur = shadowBlur
        self.shadowSpread = shadowSpread
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        self.offset = offset
        self.scale = scale
        self.rotation = rotation
        self.rotationAxis = rotationAxis
        self.transformOrigin = transformOrigin
        self.affine = affine
        self.dirty = false
    }
}

struct Border {

}

enum BorderStyle {

}
