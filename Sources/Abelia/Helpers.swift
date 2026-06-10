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
extension Vulkan.Extent2D: @unchecked @retroactive Sendable {}
extension Vulkan.Extent2D {
    static let zero = Self(width: 0, height: 0)

    func clamped(from lowerBound: Self, to upperBound: Self) -> Self {
        Self(
            width: width.clamped(from: lowerBound.width, to: upperBound.width),
            height: height.clamped(from: lowerBound.height, to: upperBound.height)
        )
    }
}
extension Vulkan.Offset2D: @unchecked @retroactive Sendable {}
extension Vulkan.Offset2D {
    static let zero = Self(x: 0, y: 0)
}
extension Comparable {
    func clamped(from lowerBound: Self, to upperBound: Self) -> Self {
        max(min(upperBound, self), lowerBound)
    }
}
extension Vulkan.Device {
    func createShaderModule(filename: String) -> ShaderModule? {
        let url = Bundle.module.url(
            forResource: "Resources/Shaders/\(filename)", withExtension: "spv")!

        guard let shaderData = try? Data(contentsOf: url) else {
            return nil
        }

        return try? shaderData.withUnsafeBytes { bytes in
            try self.createShaderModule(
                .init(
                    codeSize: bytes.count,
                    code: bytes.baseAddress!.assumingMemoryBound(to: UInt32.self)
                )
            )
        }
    }
}
extension Vulkan.Rect2D: @unchecked @retroactive Sendable {}
extension Vulkan.Rect2D {
    static let zero = Rect2D(offset: .zero, extent: .zero)
}
struct SequenceChain<First: Sequence, Second: Sequence>: Sequence
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
