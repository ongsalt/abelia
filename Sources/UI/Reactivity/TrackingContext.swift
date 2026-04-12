class TrackingContext {
    // FIXME: well this is not threadsafe since the beginning, maybe i'll think about this
    nonisolated(unsafe) static let shared: TrackingContext = TrackingContext()
    // TODO: thread local context

    var currentEffectScope: EffectScope?
    var currentSubscriber: (any Subscriber)?

    func push(scope: EffectScope? = nil, subscriber: (any Subscriber)? = nil) -> () -> Void {
        let p1 = currentEffectScope
        let p2 = currentSubscriber

        if let scope {
            currentEffectScope = scope
        }

        if let subscriber {
            currentSubscriber = subscriber
        }

        return {
            self.currentEffectScope = p1
            self.currentSubscriber = p2
        }
    }
}

private class Defer {
    let fn: () -> Void

    init(fn: @escaping () -> Void) {
        self.fn = fn
    }

    deinit {
        fn()
    }
}

func untrack(context: TrackingContext = TrackingContext.shared, _ fn: () -> Void) {
    let previousScope = context.currentEffectScope
    let previousSubscriber = context.currentSubscriber

    context.currentEffectScope = nil
    context.currentSubscriber = nil

    defer {
        context.currentEffectScope = previousScope
        context.currentSubscriber = previousSubscriber
    }

    return fn()
}
