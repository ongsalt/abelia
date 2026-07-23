import Foundation

// pure
@propertyWrapper
public class Signal<T>: Identifiable, Source<T> {
    private var _value: T
    public var untracked: T { _value }
    public var value: T {
        get {
            if let listener = TrackingContext.currentSubsciber {
                self.subscribers.append(WeakSink(listener))
            }
            return _value
        }
        set {
            if !_eq(_value, newValue) {
                _value = newValue
                notify(&subscribers)
            }
        }
    }

    // should be weak?
    var subscribers: [WeakSink] = []

    public var _eq: ((borrowing T, borrowing T) -> Bool)

    public init(_ value: T) where T: Equatable {
        self._value = value
        _eq = { a, b in a == b }
    }

    public init(_ value: T) {
        self._value = value
        _eq = { _, _ in false }
    }

    // property wrapper
    public var wrappedValue: T {
        _read {
            yield value
        }
        _modify {
            yield &value
        }
    }

    convenience public init(wrappedValue: T) {
        self.init(wrappedValue)
    }
}

public class Computed<T>: Identifiable, Source<T>, Sink {
    var dependencies: [any EdgeProtocol] = []
    var subscribers: [WeakSink] = []
    var dirty: Bool = true
    var computation: () -> T

    var _value: T!

    public var untracked: T {
        if self.dirty {
            update()
        }
        return _value
    }

    public var value: T {
        if let listener = TrackingContext.currentSubsciber {
            self.subscribers.append(WeakSink(listener))
        }
        return untracked
    }

    public init(computation: @escaping () -> T) where T: Equatable {
        self.computation = computation
        _eq = { a, b in a == b }
    }

    public init(computation: @escaping () -> T) {
        self.computation = computation
        _eq = { _, _ in false }
    }

    public var _eq: ((borrowing T, borrowing T) -> Bool)

    public func markDirty() {
        if self.dirty { return }
        notify(&subscribers)
    }

    func trackRead(_ source: some Source) {
        self.dependencies.append(Edge(source))
    }

    func update() {
        // reevaluate all source
        // compare it to last known value
        // if nothing changed return
        if !dependencies.contains(where: { $0.isChanged }) && !dependencies.isEmpty {
            return
        }

        dependencies = []
        let prev = TrackingContext.currentSubsciber
        TrackingContext.currentSubsciber = self
        defer {
            TrackingContext.currentSubsciber = prev
        }

        dirty = false
        _value = self.computation()
    }
}

struct Edge<T>: EdgeProtocol {
    let source: any Source<T>
    let savedValue: T

    init(_ source: some Source<T>) {
        self.source = source
        self.savedValue = source.value
    }

    var isChanged: Bool {
        !source._eq(savedValue, source.value)
    }
}

protocol EdgeProtocol {
    var isChanged: Bool { get }
}

enum TrackingContext {
    nonisolated(unsafe) static var currentSubsciber: (any Sink)? {
        get {
            Thread.current.threadDictionary["Abelia.ReactivityGraph.TrackingContext.current"]
                as? (any Sink)
        }
        set {
            Thread.current.threadDictionary["Abelia.ReactivityGraph.TrackingContext.current"] =
                newValue
        }
    }
}

public protocol Source<T>: AnyObject {
    associatedtype T
    var value: T { get }
    var untracked: T { get }

    var _eq: ((borrowing T, borrowing T) -> Bool) { get }

}

public protocol Sink: AnyObject {
    func markDirty()
}

// func api() {
//     let a = source(1)
//     let b = computed { a.value + 1 }
// }

struct WeakSink {
    weak var value: (any Sink)?
    init(_ value: any Sink) {
        self.value = value
    }
}

func notify(_ subscribers: inout [WeakSink]) {
    var indices: [Int] = []
    for (index, s) in subscribers.enumerated() {
        if let value = s.value {
            value.markDirty()
        } else {
            indices.append(index)
        }
    }

    for index in indices.reversed() {
        subscribers.remove(at: index)
    }
}
