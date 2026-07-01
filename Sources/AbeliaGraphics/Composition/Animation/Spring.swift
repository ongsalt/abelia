@MainActor
public class SpringAnimator<T: VectorSpace> {
    var simulation: SpringSimulation<T>
    let controller: CompositorAnimationController

    public var value: T {
        get {
            simulation.current
        }
        set {
            if simulation.isFinished {
                controller.add(simulation)
            }
            simulation.target = newValue
            simulation.velocity = (simulation.target - simulation.current)
        }
    }

    public init(value: T, controller: CompositorAnimationController) {
        self.simulation = SpringSimulation()
        simulation.current = value
        simulation.target = value
        simulation.isFinished = true

        self.controller = controller
    }
}

public class SpringSimulation<T: VectorSpace>: AnimationFrameUpdatable {
    var mass: Double = 1
    var damping: Double = 1
    var stiffness: Double = 1
    var visibilityThreshold: T.Scalar = 1

    var target: T = .zero {
        didSet {
            isFinished = false
        }
    }
    var current: T = .zero
    var velocity: T = .zero

    var setter: ((T) -> Void)?

    public var isFinished: Bool = true

    public func update(deltaTime: Duration) {
        if abs(target - current).magnitude < 1 {
            current = target
            isFinished = true
            return
        }

        let dt = (deltaTime / .seconds(1))

        current += velocity * T.Scalar(dt)
        if current > target {
            current = target
            isFinished = true
        }
    }
}
// compositor.createAnimation
// it only gauranteed to be called

public protocol AnimationFrameUpdatable {
    var isFinished: Bool { get }

    // will be nil the first frame
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

public protocol VectorSpace: AdditiveArithmetic & Comparable & SignedNumeric {
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
