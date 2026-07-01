@MainActor
public class SpringAnimator<T: VectorSpace> {
    var simulation: SpringSimulation<T>
    let controller: CompositorAnimationController

    /// How long (in seconds) the spring takes to settle. Lower is snappier/stiffer,
    /// higher is looser/softer. Mutates stiffness and damping under the hood.
    public var response: T.Scalar {
        get { simulation.response }
        set { simulation.response = newValue }
    }

    /// 1 = critically damped (no overshoot), <1 = bouncy, >1 = sluggish.
    public var dampingRatio: T.Scalar {
        get { simulation.dampingRatio }
        set { simulation.dampingRatio = newValue }
    }

    public var value: T {
        get {
            simulation.current
        }
        set {
            if simulation.isFinished {
                controller.add(simulation)
            }
            simulation.target = newValue
        }
    }

    public init(
        value: T,
        response: T.Scalar = 0.5,
        dampingRatio: T.Scalar = 1,
        controller: CompositorAnimationController
    ) {
        self.simulation = SpringSimulation()
        simulation.current = value
        simulation.target = value
        simulation.isFinished = true
        simulation.response = response
        simulation.dampingRatio = dampingRatio

        self.controller = controller
    }
}

/// A mass-spring-damper simulation: m * x'' + c * x' + k * (x - target) = 0
public class SpringSimulation<T: VectorSpace>: AnimationFrameUpdatable {
    var mass: T.Scalar = 1 {
        didSet { updateCoefficients() }
    }

    /// 1 = critically damped (no overshoot), <1 = bouncy, >1 = sluggish.
    var dampingRatio: T.Scalar = 1 {
        didSet { updateCoefficients() }
    }

    /// Approximate settling time in seconds. Mutates `stiffness`/`damping`.
    var response: T.Scalar = 0.5 {
        didSet { updateCoefficients() }
    }

    private(set) var stiffness: T.Scalar = 1
    private(set) var damping: T.Scalar = 1

    var positionThreshold: T.Scalar = 0.01
    var velocityThreshold: T.Scalar = 0.01

    var target: T = .zero {
        didSet {
            isFinished = false
        }
    }
    var current: T = .zero
    var velocity: T = .zero

    var setter: ((T) -> Void)?

    public var isFinished: Bool = true

    // Integrating in fixed substeps keeps the simulation stable even when a
    // frame takes unusually long (e.g. after a stall), instead of the spring
    // blowing up or tunnelling past its target.
    private let maxSubstep: T.Scalar = 1.0 / 120.0

    public init() {
        updateCoefficients()
    }

    private func updateCoefficients() {
        let angularFrequency = 2 * T.Scalar.pi / response
        stiffness = mass * angularFrequency * angularFrequency
        damping = 2 * dampingRatio * (stiffness * mass).squareRoot()
    }

    public func update(deltaTime: Duration) {
        guard !isFinished else { return }

        var remaining = T.Scalar(deltaTime / .seconds(1))
        guard remaining > 0 else { return }

        while remaining > 0 {
            let step = min(remaining, maxSubstep)
            integrate(dt: step)
            remaining -= step
        }

        if isAtRest {
            current = target
            velocity = .zero
            isFinished = true
        }
    }

    private func integrate(dt: T.Scalar) {
        let displacement = current - target
        let springForce = -stiffness * displacement
        let dampingForce = -damping * velocity
        let acceleration = (springForce + dampingForce) * (1 / mass)

        // Semi-implicit (symplectic) Euler: update velocity first, then use
        // it to update position. More stable than explicit Euler for springs.
        velocity += acceleration * dt
        current += velocity * dt
    }

    private var isAtRest: Bool {
        abs(current - target).magnitude < positionThreshold
            && abs(velocity).magnitude < velocityThreshold
    }
}
