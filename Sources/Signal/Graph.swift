@MainActor
class Graph: EffectOwner {
    @MainActor static var currentEffectOwner: EffectOwner? = nil
    private var effects: [Effect] = []

    init(run fn: () -> Void) {
        Graph.run(with: self, fn: fn)
    }

    func add(_ effect: Effect) {
        effects.append(effect)
    }

    func dispose() {
        effects = []
    }

    static func run(with owner: EffectOwner? = nil, fn: () -> Void) {
        let prev = Graph.currentEffectOwner
        Graph.currentEffectOwner = owner
        fn()
        Graph.currentEffectOwner = prev
    }
}
