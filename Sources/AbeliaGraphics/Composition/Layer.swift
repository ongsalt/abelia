struct LayerDirtyFlags: OptionSet {
    let rawValue: UInt32

    static let parentTransformation = LayerDirtyFlags(rawValue: 1 << 0)
    static let position = LayerDirtyFlags(rawValue: 1 << 0)
    static let size = LayerDirtyFlags(rawValue: 1 << 0)
    static let contents = LayerDirtyFlags(rawValue: 1 << 0)
}

// TODO: move layer dimension calculating to render thread
public class Layer: Identifiable {
    var compositor: Compositor? {
        didSet {
            if let compositor {
                for c in children {
                    c.compositor = compositor
                }
            }
        }
    }

    private(set) var renderNode: RenderNode?

    public var label: String?
    /// currently just redraw everything
    var dirtyFlags: LayerDirtyFlags = []

    private(set) var parent: Layer!
    private(set) var children: [Layer] = []

    public var offset: SIMD2<Float> = .zero
    public var size: SIMD2<Float> = .zero

    public func insert(_ layer: Layer, before: Layer? = nil) {
        compositor?.markDirty(layer)
        children.append(layer)
        layer.parent = self
    }

    public func remove(_ layer: Layer) {
        layer.parent = nil
        children.removeAll { $0.id == layer.id }
        compositor?.markDirty(self)
    }
}

@MainActor
class SpriteLayer: Layer {
    // var brush: Brush
}

@resultBuilder
public struct LayerBuilder {
    public static func buildBlock(_ layers: Layer...) -> [Layer] { layers }
    public static func buildArray(_ layers: [[Layer]]) -> [Layer] { layers.flatMap { $0 } }
    public static func buildOptional(_ layers: [Layer]?) -> [Layer] { layers ?? [] }
    public static func buildEither(first layers: [Layer]) -> [Layer] { layers }
    public static func buildEither(second layers: [Layer]) -> [Layer] { layers }
}

extension Layer: CustomStringConvertible {
    nonisolated public var description: String {
        let name = label ?? "(unnamed)"
        let offset = (self.offset.x, self.offset.y)
        let size = (self.size.x, self.size.y)
        return "\(Self.self)[\(name)] offset=\(offset) size=\(size)"
    }
}

extension Layer {
    public func printDebugInfo(indent: Int = 0) {
        let prefix = String(repeating: "  ", count: indent)
        print("\(prefix)\(description)")
        for child in children {
            child.printDebugInfo(indent: indent + 1)
        }
    }

    public convenience init(
        offset: SIMD2<Float> = .zero,
        size: SIMD2<Float> = .zero,
        @LayerBuilder children: () -> [Layer] = { [] }
    ) {
        self.init()
        self.offset = offset
        self.size = size
        for child in children() {
            insert(child)
        }
    }
}

// MARK: walking
// dfs preorder, for calculating accumulated transformation
@MainActor
public func sortLayer(_ root: Layer) -> [LayerGrouping] {
    var layers: [LayerGrouping] = []

    func walk(_ layer: Layer) {
        if layer.children.isEmpty {
            layers.append(.layer(layer))
        } else {
            layers.append(.push(layer))
            for c in layer.children {
                walk(c)
            }
            layers.append(.pop)
        }
    }

    walk(root)
    return layers
}

public enum LayerGrouping {
    case layer(Layer)
    case push(Layer)
    case pop
}
