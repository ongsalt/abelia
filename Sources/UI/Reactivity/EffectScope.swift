open class EffectScope {
    weak var parent: (EffectScope)?
    var children: [EffectScope] = []

    public init() {
        self.parent = TrackingContext.shared.currentEffectScope
        self.parent?.addChildren(effect: self)
    }

    convenience public init(_ fn: @escaping () -> Void) {
        self.init()

        let pop = TrackingContext.shared.push(scope: self)
        defer {
            pop()
        }

        fn()
    }

    func addChildren(effect: EffectScope) {
        self.children.append(effect)
    }

    public func destroy() {
        for c in children {
            c.destroy()
        }
        children = []
    }
}
