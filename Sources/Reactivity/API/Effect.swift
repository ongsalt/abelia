public class Effect {
    let node: Node = Node(label: String(describing: Effect.self))

    @discardableResult
    public init(_ block: @escaping () -> Void) {
        node.dirtyCallback = { [weak node] in
            node?.clearDependencies()
            let deps = TrackingContext.track {
                block()
            }
            node?.addDependency(deps)
            node?.markClean()
        }

        node.dirtyCallback?()
    }

    public func stop() {
        node.dirtyCallback = nil
        node.clearDependencies()
    }

    deinit {
        node.dirtyCallback = nil
        node.clearDependencies()
    }
}
