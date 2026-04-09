import Observation

@Observable
class Signal<T>: Source {
    public var value: T

    @ObservationIgnored
    public var peek: T {
        _value
    }

    public init(_ value: T) {
        self.value = value
    }
}
