import Observation

@Observable
public class Computed<T>: Source {
    @ObservationIgnored
    let fn: () -> T

    @ObservationIgnored
    private var dirty: Bool = true

    private var innerValue: T = trustMeBroItIsInitialized()

    public var value: T {
        updateIfNeeded()
        return innerValue
    }

    @ObservationIgnored
    public var peek: T {
        updateIfNeeded()
        return _innerValue
    }

    public init(_ fn: @escaping () -> T) {
        self.fn = fn
        track()
    }

    public init(expression: @autoclosure @escaping () -> T) {
        self.fn = expression
        track()
    }

    private func updateIfNeeded() {
        if self.dirty {
            self.dirty = false
            innerValue = fn()
        }
    }

    private func track() {
        _ = withObservationTracking {
            fn()
        } onChange: {
            // Schedule flush????
            Task { @MainActor [weak self] in
                self?.dirty = true
                self?.track()
            }
        }
    }
}
