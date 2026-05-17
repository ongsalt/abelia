@MainActor
public class Effect {
    nonisolated(unsafe) let node: Node = Node(label: String(describing: Effect.self))
    let block: () -> Void

    // @discardableResult
    public init(_ block: @escaping () -> Void) {
        self.block = block
        node.dirtyCallback = {
            // TODO make a nextTick { ... }
            Task {
                self.update()
            }
        }

        self.update()
    }

    func update() {
        node.clearDependencies()
        let deps = TrackingContext.track {
            block()
        }
        node.addDependency(deps)
        node.markClean()
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
