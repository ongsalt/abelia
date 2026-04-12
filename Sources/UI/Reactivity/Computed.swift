public class Computed<T>: EffectScope, Source, Subscriber {
    internal var subscribers: [Int: any Subscriber] = [:]
    internal var dependencies: [Int: any Source] = [:]
    private let tags: [String]?
    let fn: () -> T

    private var dirty = true

    private lazy var innerValue: T = compute()
    public var value: T {
        track()
        if dirty {
            innerValue = compute()
            dirty = false
        }
        return innerValue
    }

    public var peek: T {
        innerValue
    }

    public init(tags: [String]? = nil, _ fn: @escaping () -> T) {
        self.tags = tags
        self.fn = fn
        super.init()
    }

    override public func destroy() {
        let deps = dependencies.values
        for d in deps {
            Effect.unlink(source: d, subscriber: self)
        }

        super.destroy()
    }

    func track() {
        guard let subscriber = TrackingContext.shared.currentSubscriber else {
            return
        }

        Effect.link(source: self, subscriber: subscriber)
    }

    func trigger() {
        let left = subscribers.values
        subscribers = [:]
        for s in left {
            s.update()
        }
    }

    func update() {
        self.dirty = true
        // TODO: detect change for T: Eq

        trigger()
    }

    func compute() -> T {
        let pop = TrackingContext.shared.push(scope: self, subscriber: self)
        defer {
            pop()
        }

        dependencies = [:]
        return self.fn()
    }
}
