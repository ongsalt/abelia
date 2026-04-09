@MainActor
protocol EffectOwner {
    func add(_ effect: Effect)
    func dispose()
}

