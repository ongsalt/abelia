import ReactivityGraph

// TODO: move layer dimension calculating to render thread

public class _BaseLayer: Identifiable {
    public var id: Int {
        Int(bitPattern: ObjectIdentifier(self))
    }

    // TODO: make each layer appear only once in a given tree
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
    var dirtyFlags: LayerDirtyFlags = [.transform, .draw]

    public var shouldRasterize: Bool = false {
        didSet { dirtyFlags.insert(.compositionGroup) }
    }

    /// Clips descendants to a geometry, evaluated directly as an SDF in the fragment shader (no
    /// offscreen pass). Modeled after Windows.UI.Composition `Visual.Clip`: `nil` means no clip.
    /// Clips nest — a fragment survives only inside every clipping ancestor.
    @Bindable
    public var clip: LayerClip? = nil {
        didSet { dirtyFlags.insert(.draw) }
    }

    /// This layer's own clip resolved to a shape in its local (center-origin) space plus the
    /// transform into world/pass space. `nil` when the layer does not clip.
    var resolvedClip: Computed<ClipShape?>!

    private(set) var parent: _BaseLayer?
    var offscreenParent: OffscreenLayer?
    private(set) var children: [_BaseLayer] = []

    public var shape: any ShapeProtocol {
        Shape.rect(width: size.x, height: size.y)
    }

    var bounds: Rect {
        return shape.bounds.atOrigin
    }

    @Bindable
    public var offset: SIMD3<Float> = .zero {
        didSet { dirtyFlags.insert(.transform) }
    }

    @Bindable
    public var size: SIMD2<Float> = .zero {
        didSet { dirtyFlags.insert(.transform) }
    }

    @Bindable
    public var scale: SIMD2<Float> = .one {
        didSet { dirtyFlags.insert(.transform) }
    }

    @Bindable
    public var rotation: Angle = .radians(0) {
        didSet { dirtyFlags.insert(.transform) }
    }

    @Bindable
    public var rotationAxis: SIMD3<Float> = [0, 0, 1] {
        didSet { dirtyFlags.insert(.transform) }
    }

    /// pivot point for scale and rotation, in local space — behaves like CSS transform-origin
    @Bindable
    public var transformOrigin: SIMD2<Float> = SIMD2(0.5, 0.5) {
        didSet { dirtyFlags.insert(.transform) }
    }

    // TODO: backfaceVisibility
    @Bindable
    public var affine: Affine = .identity {
        didSet { dirtyFlags.insert(.transform) }
    }

    // in parent space, relative to self
    @Bindable
    public var anchor: SIMD2<Float> = .zero {
        didSet { dirtyFlags.insert(.transform) }
    }

    // For children
    @Bindable
    public var origin: SIMD3<Float> = .zero {
        didSet { dirtyFlags.insert(.transform) }
    }

    var effectiveOpacity: Computed<Float>!
    var accumulatedOpacity: Computed<Float>!

    var effectiveTransform: Computed<Affine>!
    var accumulatedTransform: Computed<Affine>!

    /// Clip stack this layer hands to its descendants: the stack applying to its own content plus
    /// its own clip if any. A non-clipping layer forwards the parent's *same* instance so an entire
    /// subtree shares one `ClipStack` (letting the renderer write it once). Resets at offscreen
    /// boundaries — those clips apply to the composited quad in the parent pass instead.
    var contributedClipStack: Computed<ClipStack>!

    /// Clip stack applying to this layer's own content (what its parent contributes).
    var contentClipStack: ClipStack {
        parent?.contributedClipStack.value ?? .empty
    }

    init() {
        accumulatedTransform = Computed { [unowned self] in
            let o = transformOrigin * size

            return (parent?.accumulatedTransform.value ?? .identity)
                .translated(x: offset.x, y: offset.y, z: offset.z)
                .translated(x: o.x, y: o.y)
                .multiplied(by: affine)
                .rotated(rotation, axis: rotationAxis)
                .scaled(x: scale.x, y: scale.y)
                .translated(x: -o.x, y: -o.y)
        }

        effectiveTransform = Computed { [unowned self] in
            let d = (0.5 - anchor) * size
            return
                accumulatedTransform.value
                .translated(x: d.x, y: d.y)
        }

        accumulatedOpacity = Computed { [unowned self] in
            parent?.accumulatedOpacity.value ?? 1.0
        }

        effectiveOpacity = Computed { [unowned self] in
            self.accumulatedOpacity.value
        }

        resolvedClip = Computed { [unowned self] in
            guard let clip else { return nil }
            let world = Transform2D(effectiveTransform.value)
            switch clip {
            case .bounds:
                return ClipShape(shape: shape, transform: world)
            case .shape(let s):
                return ClipShape(shape: s, transform: world)
            case .inset(let top, let right, let bottom, let left, let cornerRadius):
                let center = SIMD2<Float>((left - right) / 2, (top - bottom) / 2)
                return ClipShape(
                    shape: Shape.rect(
                        width: size.x - left - right, height: size.y - top - bottom,
                        cornerRadius: cornerRadius),
                    transform: world.concatenating(.translation(center)))
            }
        }

        contributedClipStack = Computed { [unowned self] in
            // an offscreen layer begins a new pass in its own coordinate space; ancestor clips
            // apply to its composited quad, not inline to its subtree — so children start fresh.
            if self is OffscreenLayer { return .empty }
            let base = parent?.contributedClipStack.value ?? .empty
            guard let own = resolvedClip.value else { return base }  // no clip: forward parent's instance
            return ClipStack(base.shapes + [own])
        }
    }

    @Bindable
    public var hidden: Bool = false

    public func insert(_ layer: _BaseLayer, before: _BaseLayer? = nil) {
        children.append(layer)
        layer.parent = self

        if let s = self as? OffscreenLayer {
            layer.offscreenParent = s
            s.offscreenChildren.append(layer)
        } else {
            layer.offscreenParent = self.offscreenParent
            self.offscreenParent?.offscreenChildren.append(layer)
        }

        layer.compositor = self.compositor
    }

    public func insert(before: _BaseLayer? = nil, @LayerBuilder builder: () -> [_BaseLayer]) {
        for layer in builder() {
            insert(layer, before: before)
        }
    }

    public func remove(_ layer: _BaseLayer) {
        layer.parent = nil
        layer.offscreenParent = nil
        layer.compositor = nil
        children.removeAll { $0.id == layer.id }

        if let s = self as? OffscreenLayer {
            s.offscreenChildren.removeAll { $0.id == layer.id }
        } else {
            self.offscreenParent?.offscreenChildren.removeAll { $0.id == layer.id }
        }
    }
}

public enum Anchor {
    case topLeft
    case topCenter
    case topRight
    case centerLeft
    case center
    case centerRight
    case bottomLeft
    case bottomCenter
    case bottomRight
    case custom(Float, Float)

    var unitCoordinates: (x: Float, y: Float) {
        switch self {
        case .topLeft: (0.0, 0.0)
        case .topCenter: (0.5, 0.0)
        case .topRight: (1.0, 0.0)
        case .centerLeft: (0.0, 0.5)
        case .center: (0.5, 0.5)
        case .centerRight: (1.0, 0.5)
        case .bottomLeft: (0.0, 1.0)
        case .bottomCenter: (0.5, 1.0)
        case .bottomRight: (1.0, 1.0)
        case .custom(let x, let y): (x, y)
        }
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
    static let draw = LayerDirtyFlags(rawValue: 1 << 1)
    static let compositionGroup = LayerDirtyFlags(rawValue: 1 << 2)
}
