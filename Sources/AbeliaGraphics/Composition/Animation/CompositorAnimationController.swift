
public protocol AnimationFrameUpdatable {
    var isFinished: Bool { get }

    mutating func update(deltaTime: Duration)
}

@MainActor
public class CompositorAnimationController {
    let compositor: Compositor
    let clock = ContinuousClock()
    var lastAnimationFrameTime: ContinuousClock.Instant
    var listeners: [any AnimationFrameUpdatable] = []

    public init(_ compositor: Compositor) {
        self.compositor = compositor
        lastAnimationFrameTime = clock.now
    }

    public func add(_ listener: any AnimationFrameUpdatable) {
        if listeners.isEmpty {
            self.lastAnimationFrameTime = clock.now
            compositor.requestAnimationFrame {
                self.runAnimationFrame()
            }
        }

        listeners.append(listener)
    }

    private func runAnimationFrame() {
        let now = clock.now
        let dt = now - self.lastAnimationFrameTime

        var finishedIndices: [Int] = []
        for index in listeners.indices {
            listeners[index].update(deltaTime: dt)
            if listeners[index].isFinished {
                finishedIndices.append(index)
            }
        }

        for index in finishedIndices.lazy.reversed() {
            listeners.remove(at: index)
        }

        if !listeners.isEmpty {
            self.lastAnimationFrameTime = now
            compositor.requestAnimationFrame {
                self.runAnimationFrame()
            }
        }
    }
}

public protocol VectorSpace: AdditiveArithmetic & Comparable & SignedNumeric where Magnitude == Scalar {
    associatedtype Scalar: BinaryFloatingPoint
    static func * (lhs: Self, rhs: Scalar) -> Self
    static func * (lhs: Scalar, rhs: Self) -> Self
}

extension Float: VectorSpace {
    public typealias Scalar = Float
}

extension Double: VectorSpace {
    public typealias Scalar = Double
}
