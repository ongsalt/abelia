import Foundation
import Vulkan

extension Optional {
    func orThrow<E>(_ error: @autoclosure () -> E) throws(E) -> Wrapped {
        if let value = self {
            return value
        }
        throw error()
    }
}

extension Swift.Result {
    func mapFailure<E>(_ map: (Failure) -> E) -> Swift.Result<Success, E> {
        switch self {
        case .success(let v): .success(v)
        case .failure(let e): .failure(map(e))
        }
    }

    init(throwing: Failure.Type, _ body: () throws(Failure) -> Success) {
        do {
            self = .success(try body())
        } catch {
            self = .failure(error)
        }
    }
}

extension Comparable {
    func clamped(from lowerBound: Self, to upperBound: Self) -> Self {
        max(min(upperBound, self), lowerBound)
    }
}

public struct SequenceChain<First: Sequence, Second: Sequence>: Sequence
where First.Element == Second.Element {
    @usableFromInline let first: First
    @usableFromInline let second: Second

    @inlinable init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public struct Iterator: IteratorProtocol {
        @usableFromInline var first: First.Iterator
        @usableFromInline var second: Second.Iterator

        @usableFromInline init(_ first: First.Iterator, _ second: Second.Iterator) {
            self.first = first
            self.second = second
        }

        @inlinable public mutating func next() -> First.Element? {
            first.next() ?? second.next()
        }
    }

    @inlinable public func makeIterator() -> Iterator {
        Iterator(first.makeIterator(), second.makeIterator())
    }
}

extension Sequence {
    @inlinable
    public func chain<Other: Sequence<Element>>(_ other: Other) -> SequenceChain<Self, Other> {
        SequenceChain(self, other)
    }
}

func measure<T>(block: () -> T) -> (Duration, T) {
    let clock = ContinuousClock()
    var ret: T!
    let time = clock.measure {
        ret = block()
    }
    return (time, ret)
}
