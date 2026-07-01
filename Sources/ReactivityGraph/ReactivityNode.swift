// pure

class _Cell<T: Equatable>: Identifiable, Source<T> {
    var value: T
    var subscribers: [any Sink] = []

    init(_ value: T) {
        self.value = value
    }
}

class _Thunk<T: Equatable>: Identifiable, Source<T>, Sink {
    var dependencies: [Edge] = []
    var subscribers: [any Sink] = []
    var dirty: Bool = true
    var computation: () -> T

    var value: T {
        fatalError()
    }

    init(computation: @escaping () -> T) {
        self.computation = computation
    }

    func markDirty() {

    }

    func trackRead(_ source: some Source) {
        dependencies.append(Edge(source: source))
    }

}

struct Edge {
    let source: any Source
}

public protocol Source<T> {
    associatedtype T: Equatable
    var value: T { get }
}

protocol Sink {
    func markDirty()

    @inline(always)
    func trackRead(_ source: some Source)
}

// func api() {
//     let a = source(1)
//     let b = computed { a.value + 1 }
// }
