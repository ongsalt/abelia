@MainActor
class Layer: Identifiable {
    unowned var parent: Layer? = nil
    var children: [Layer] = []

    unowned var compositor: Compositor? = nil {
        didSet {
            compositor?.invalidateLayer(layer: self, invalidation: .existence)
            for c in self.children {
                c.compositor = compositor
            }
        }
    }

    var z: Float = 1
    // inner size
    var bounds: Rect = .zero {  // mostly always at 0,0 TODO: make it not
        didSet {
            invalidate(.transformations)
        }
    }

    // TODO: calculate this with transform
    // outer size
    var frame: Rect {
        bounds.atOrigin.offset(position)
    }

    var position: SIMD2<Float> = .zero {
        didSet {
            invalidate(.transformations)
        }
    }

    var absoluteFrame: Rect {
        // TODO: affine transform
        frame.offset(parent?.absoluteFrame.topLeft ?? .zero)
    }

    var scale: Float = 1
    var rotation: Float = 0
    var opacity: Float = 1
    var isHidden: Bool = false
    var mask: Layer? = nil
    var clipChildren: Bool = true
    var cornerRadius: Float = 0 {
        didSet {
            invalidate(.paint)
        }
    }

    var cornerDegree: Float = 4 {
        didSet {
            invalidate(.paint)
        }
    }

    var borderWidth: Float = 0
    var borderColor: Color = .transparent

    var shadowColor: Color = .transparent {
        didSet {
            invalidate(.paint)
        }
    }

    var shadowBlur: Float = 0 {
        didSet {
            invalidate(.paint)
        }
    }

    var shadowOffset: SIMD2<Float> = .zero {
        didSet {
            invalidate(.paint)
        }
    }

    var backgroundColor: Color = .transparent {
        didSet {
            invalidate(.paint)
        }
    }

    var transformations: AffineMatrix = .identity
    var totalTransformation: AffineMatrix {
        transformations * mtx
    }

    private var mtx: AffineMatrix {
        var mtx = AffineMatrix.identity
        mtx.scale(x: scale, y: scale, z: scale)
        mtx.rotate(angleRadians: rotation, axis: [0, 0, 1])
        return mtx
    }
    // how to do brush tho

    // var shadow: Shadow
    // lightingggggg

    // TODO: contents positioning
    var contents: (any LayerContents)?
    // var contentsRect: Rect = .unit

    // var filters: [Any] = []
    // var backdropFilters: [Any] = []

    // var shouldRasterize: Bool = false

    init() {
    }

    convenience init(rect: Rect) {
        self.init()
        // self.frame = rect
        // TODO: fix this
        self.bounds = rect
        self.position = rect.topLeft
    }

    func addChild(_ layer: Layer, after position: Int? = nil) {
        if let position {
            children.insert(layer, at: position)
        } else {
            children.append(layer)
        }

        layer.parent = self

        if let compositor {
            layer.compositor = compositor
            // compositor.invalidateLayer(layer: layer, invalidation: .existence)
        }
    }

    func removeChild(_ layer: Layer) {
        guard let index = children.firstIndex(of: layer) else {
            return
        }

        self.children.remove(at: index)
        layer.parent = nil
    }

    func invalidate(_ type: Invalidation) {
        compositor?.invalidateLayer(layer: self, invalidation: type)
    }

    func getLayerDrawCommands(transformation: AffineMatrix) -> [DrawCommand] {
        var commands: [DrawCommand] = []

        let inverseTransform = transformation.fastInverse()

        if shadowBlur > 0 && shadowColor.a > 0 {
            let shadow = RoundedRectangleDrawCommand(
                color: duplicated(self.shadowColor.premulitplied()),
                center: self.absoluteFrame.center,
                size: self.absoluteFrame.size * scale,
                borderRadius: self.cornerRadius,
                rotation: self.rotation,
                borderWidth: 0,
                borderColor: .transparent,
                shadowBlur: self.shadowBlur * scale,
                shadowOffset: self.shadowOffset * scale,
                cornerDegree: self.cornerDegree,
                transform: inverseTransform,
                mode: 1
            )
            commands.append(DrawCommand.roundedRectangle(shadow))
        }

        let bg = RoundedRectangleDrawCommand(
            color: duplicated(self.backgroundColor.multiply(opacity: opacity).premulitplied()),
            center: self.absoluteFrame.center,
            size: self.absoluteFrame.size * scale,
            borderRadius: self.cornerRadius,
            rotation: self.rotation,
            borderWidth: self.borderWidth * scale,
            borderColor: self.borderColor.premulitplied(),
            shadowBlur: 0,
            shadowOffset: .zero,
            cornerDegree: self.cornerDegree,
            transform: inverseTransform,
            mode: 0
        )
        commands.append(DrawCommand.roundedRectangle(bg))

        return commands
    }
}

extension Layer: Equatable {
    nonisolated static func == (lhs: Layer, rhs: Layer) -> Bool {
        lhs.id == rhs.id
    }
}

extension Layer: Hashable {
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
