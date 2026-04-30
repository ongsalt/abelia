import Composition

// yep this is Compose's LayoutNode
@MainActor
public class LayoutNode: Identifiable {
    var parent: LayoutNode?
    public var children: [LayoutNode] = []
    let measurementPolicy: MeasurementPolicy

    let draw: ((Rect) -> Void)?

    private(set) public var renderNode: RenderNode

    init(
        measurementPolicy: MeasurementPolicy,
        renderNode: RenderNode,
        draw: ((Rect) -> Void)? = nil
    ) {
        self.measurementPolicy = measurementPolicy
        self.renderNode = renderNode
        self.draw = draw
    }

    public func appendChild(_ node: LayoutNode, after position: Int? = nil) {
        self.renderNode.addChild(node.renderNode)
        if let position {
            children.insert(node, at: position)
        } else {
            children.append(node)
        }

        node.parent = self
        // TODO: position
        // node.parentData = ParentData()
    }

    public func removeChild(child: LayoutNode) {
        self.children.removeAll { $0.id == child.id }
        child.parent = nil
        renderNode.removeChild(child: child.renderNode)
    }

    public func removeAllChild() {
        for c in self.children {
            c.parent = nil
        }
        self.children.removeAll(keepingCapacity: true)
    }

    // dirtyFlags

    func markNeedLayout() {

    }

    func markNeedPaint() {

    }

    func layout(items: [Measurable], constraints: Constraints) -> ([Placable]) -> Void {
        return { placables in

        }
    }

    func paint() {
        // mount renderNode
        let size = Rect.zero
        self.draw?(size)
    }
}

// what if we do a reactive graph
// parent:constraints ->
//     -> child size  -> size -> parent:position, parent:size -> drawCommand

public enum MeasurementPolicy: Sendable {
    case box
    case row
    case column
    case text
    // then we gonna have transparent marker node for if/for
    // or we add "Comment node"
    case transparent
    // case ignored
    // case custom(([Any], Any) -> ([Any]) -> Void)
}

@MainActor
@Autobind2
public func Layout(
    measurementPolicy: MeasurementPolicy,
    renderNode: RenderNode? = nil,
    @ViewBuilder body: () -> Body
) -> LayoutNode {
    let node = LayoutNode(
        measurementPolicy: measurementPolicy, renderNode: renderNode ?? CompositionNode())
    let children = body()
    for c in children {
        node.appendChild(c)
    }

    return node
}

// TODO: report bug, the compiler cant generate diagnostic for this
// func Layout(measurementPolicy: MeasurementPolicy, @ViewBuilder body: () -> some View) -> LayoutNode {

@MainActor
@Autobind2
public func Box(@ViewBuilder body: () -> Body = { [] }) -> View {
    return Layout(measurementPolicy: .box, body: body)
}

@MainActor
@Autobind2
public func Row(@ViewBuilder body: () -> Body) -> View {
    return Layout(measurementPolicy: .row, body: body)
}

@MainActor
@Autobind2
public func Column(@ViewBuilder body: () -> Body) -> View {
    return Layout(measurementPolicy: .column, body: body)
}

@MainActor
@Autobind2
public func Text(_ text: Bind<String>) -> View {
    let renderNode = CompositionNode()
    let node = LayoutNode(measurementPolicy: .text, renderNode: renderNode) { rect in
        // render after we got size
        text.value
    }

    Effect {
        // renderNode.comment = text.value
        // mark relayout needed?
        // mark dirty?
        node.markNeedLayout()
    }

    return node
}

// @MainActor
// public func Counter() -> View {
//     @State
//     var count = 0

//     return Row {
//         Text("yomama")
//         Text("Count = \(count)")

//         Box {
//             Text("Increment")
//             // .onClick {

//             // }
//         }
//     }
// }

// private func layoutFnApi() {
//     func shi(measurables: [Any], constraints: Any) {

//         return layout(w, h) { (placeable: [Any]) in

//         }
//     }
// }

class Placable {
    func place(at: SIMD2<Float>, size: SIMD2<Float>) {}
}

class Measurable {
    func measure(constraints: Constraints) -> SIMD2<Float> {
        .zero
    }
}

struct LayoutInfo {

}

// func layout() -> LayoutInfo {

// }