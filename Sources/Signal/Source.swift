@MainActor
protocol Source<T> {
    associatedtype T

    var value: T {
        get
    }
}
