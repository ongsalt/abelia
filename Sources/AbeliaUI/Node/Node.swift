import AbeliaGraphics
import ReactivityGraph

// Transparent, only for organization purpose: If and For
// TODO: make each node unique, but its structurally enforced if we use functional component api
@MainActor
class Node: Identifiable {
    var runtime: Runtime?
    private(set) weak var parent: Node? {
        didSet {
            if let r = parent?.runtime {
                self.runtime = r
                for c in children {
                    c.runtime = r
                }
            }
        }
    }

    private(set) weak var layoutParent: LayoutNode?
    private(set) var children: [Node] = []

    public func appendChild(_ node: Node, after position: Int? = nil) {
        if let position {
            children.insert(node, at: position)
        } else {
            children.append(node)
        }

        node.parent = self
        if let s = self as? LayoutNode {
            node.layoutParent = s
        } else {
            node.layoutParent = self.layoutParent
        }
    }

    public func removeChild(child: Node) {
        self.children.removeAll { $0 === child }
        child.parent = nil
        child.layoutParent = nil
    }
}

@MainActor
class LayoutNode: Node {
    var layer: Layer = Layer()

    // MARK: Layout param,
    @Bindable
    var width: Float = .zero
    @Bindable
    var height: Float = .zero

    var finalOffset: SIMD2<Float> = .zero
    var finalSize: SIMD2<Float> = .zero


    override init() {
        super.init()
    }

    func bindLayerProperties() {
        layer.$offset.bind { [unowned self] in
            SIMD3(self.finalOffset, 0.0)
        }
    }

    deinit {

    }
}
