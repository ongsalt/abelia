// Normal ownership
// TODO: exclude current effect when tracking subscriber
public class Signal<T>: Source {
    internal var subscribers: [Int: any Subscriber] = [:]
    private var innerValue: T

    public var value: T {
        get {
            track()
            return innerValue
        }
        set {
            // TODO: non assignment modification
            innerValue = newValue
            trigger()
        }
    }

    public var peek: T {
        innerValue
    }

    public init(_ value: T) {
        // self.innerValue = Box(value)
        self.innerValue = value
    }

    // init<V>(_ value: V) where Box<V> == T {
    //     self._value = Box(value)
    // }

    func track() {
        guard let subscriber = TrackingContext.shared.currentSubscriber else {
            return
        }

        Effect.link(source: self, subscriber: subscriber)
    }

    public func destroy() {
        let subs = subscribers.values
        for s in subs {
            Effect.unlink(source: self, subscriber: s)
        }
        subscribers = [:]
    }

    func trigger() {
        let left = subscribers.values
        subscribers = [:]
        for s in left {
            s.update()
        }
    }

    func toReadOnly() -> ReadOnlyBinding<T> {
        ReadOnlyBinding { self.value }
    }
}
