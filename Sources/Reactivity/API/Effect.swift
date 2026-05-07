class Effect {
    let node: Node = Node(label: String(describing: Effect.self))

    @discardableResult
    init(_ block: @escaping () -> Void) {
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

    deinit {
        node.dirtyCallback = nil
    }
}
