// effect scope own it

// this shi is not thread safe
public class Effect: EffectScope, Subscriber {
    internal var dependencies: [Int: any Source] = [:]
    private let tags: [String]?
    let fn: () -> Void

    // TODO: effect priority / batching / auto flush (ui)  
    @discardableResult
    public init(priority: Int = 0, tags: [String]? = nil, _ fn: @escaping () -> Void) {
        self.tags = tags
        self.fn = fn

        super.init()
        self.update()
    }

    deinit {
        // should be automatically run after destroy becuase its refcount will be 0
        // print("[effect] deinited \(String(describing: tags))")
    }

    override public func destroy() {
        // unlink
        let deps: Dictionary<Int, any Source>.Values = dependencies.values
        for d in deps {
            Effect.unlink(source: d, subscriber: self)
        }

        for c in children {
            c.destroy()
        }

        dependencies = [:]
        children = []
    }

    func update() {
        let pop = TrackingContext.shared.push(scope: self, subscriber: self)
        defer {
            pop()
        }

        dependencies = [:]

        self.fn()
    }
}

extension Effect {
    static func link(source: any Source, subscriber: any Subscriber) {
        subscriber.addDependency(source)
        source.addSubscriber(subscriber)
    }

    static func unlink(source: any Source, subscriber: any Subscriber) {
        subscriber.removeDependency(source)
        source.removeSubscriber(subscriber)
    }
}
