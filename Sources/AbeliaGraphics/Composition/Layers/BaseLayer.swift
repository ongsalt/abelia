// TODO: move layer dimension calculating to render thread

public class _BaseLayer: Identifiable {
    public var id: Int {
        Int(bitPattern: ObjectIdentifier(self))
    }

    var compositor: Compositor? {
        didSet {
            if let compositor {
                for c in children {
                    c.compositor = compositor
                }
            }
        }
    }

    public var label: String?
    var dirtyFlags: LayerDirtyFlags = [.transform, .contents]

    public var shouldRasterize: Bool = false
    var isRasterizationRoot: Bool {
        shouldRasterize
    }

    private(set) var parent: _BaseLayer!
    private(set) var children: [_BaseLayer] = []

    public var shape: any ShapeProtocol {
        Shape.rect(width: size.x, height: size.y)
    }

    var bounds: Rect {
        return shape.bounds.atOrigin
    }

    public var offset: SIMD3<Float> = .zero {
        didSet { dirtyFlags.insert(.transform) }
    }

    public var size: SIMD2<Float> = .zero {
        didSet { dirtyFlags.insert(.transform) }
    }

    public var scale: SIMD2<Float> = .one {
        didSet { dirtyFlags.insert(.transform) }
    }

    public var rotation: Angle = .radians(0) {
        didSet { dirtyFlags.insert(.transform) }
    }

    public var rotationAxis: SIMD3<Float> = [0, 0, 1] {
        didSet { dirtyFlags.insert(.transform) }
    }

    /// pivot point for scale and rotation, in local space — behaves like CSS transform-origin
    public var transformOrigin: SIMD2<Float> = .zero {
        didSet { dirtyFlags.insert(.transform) }
    }

    // TODO: backfaceVisibility
    public var affine: Affine = .identity

    /// pivot point for scale and rotation, in local space — behaves like CSS transform-origin
    // will be computed outside on, wont include self
    var localTotalAffine: Affine {
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

    var hidden: Bool = false

    public func insert(_ layer: _BaseLayer, before: _BaseLayer? = nil) {
        children.append(layer)
        layer.parent = self
    }

    public func insert(before: _BaseLayer? = nil, @LayerBuilder builder: () -> [_BaseLayer]) {
        for layer in builder() {
            insert(layer, before: before)
        }
    }

    public func remove(_ layer: _BaseLayer) {
        layer.parent = nil
        children.removeAll { $0.id == layer.id }
    }

}

extension _BaseLayer: CustomStringConvertible {
    nonisolated public var description: String {
        let name = label ?? "(unnamed)"
        let offset = (self.offset.x, self.offset.y)
        return "\(Self.self)[\(name)] offset=\(offset)"
    }
}

extension _BaseLayer {
    public func printDebugInfo(indent: Int = 0) {
        let prefix = String(repeating: "  ", count: indent)
        print("\(prefix)\(description)")
        for child in children {
            child.printDebugInfo(indent: indent + 1)
        }
    }
}

struct LayerDirtyFlags: OptionSet {
    let rawValue: UInt32

    static let transform = LayerDirtyFlags(rawValue: 1 << 0)
    static let contents = LayerDirtyFlags(rawValue: 1 << 1)
    static let grouping = LayerDirtyFlags(rawValue: 1 << 2)
}
