// there is none. its implicit now fuck you
enum Graph {}

public class TrackingContext: @unchecked Sendable {
    @TaskLocal
    static var current: TrackingContext?

    var trackedNodes: Set<Node> = []

    func reportRead(_ node: Node) {
        trackedNodes.insert(node)
    }
}

extension TrackingContext {
    static func track(_ block: () -> Void) -> Set<Node> {
        let context = TrackingContext()
        TrackingContext.$current.withValue(context) {
            block()
        }
        return context.trackedNodes
    }

    public static func untrack<T>(_ block: () -> T) -> T {
        TrackingContext.$current.withValue(nil) {
            block()
        }
    }
}

@inline(always)
public func untrack<T>(_ block: () -> T) -> T {
    TrackingContext.untrack(block)
}
