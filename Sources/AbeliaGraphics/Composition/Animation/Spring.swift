// stolen from jetpack compose

public struct SpringConfiguration<Scalar: RealScalar> {
    public var mass: Scalar
    /// Approximate settling time in seconds. Lower is snappier/stiffer, higher is looser/softer.
    public var response: Scalar
    /// 1 = critically damped (no overshoot), <1 = bouncy, >1 = sluggish.
    public var dampingRatio: Scalar
    /// Distance from target (in the animated value's own units) below which the spring is
    /// considered at rest. The matching velocity cutoff is derived from this and `response`.
    public var visibilityThreshold: Scalar

    public init(
        mass: Scalar = 1, response: Scalar = 0.45, dampingRatio: Scalar = 1,
        visibilityThreshold: Scalar = 0.01
    ) {
        self.mass = mass
        self.response = response
        self.dampingRatio = dampingRatio
        self.visibilityThreshold = visibilityThreshold
    }

    /// Spring constant derived from `mass` and `response`: k = m * (2pi / response)^2.
    public var stiffness: Scalar {
        let angularFrequency = 2 * Scalar.pi / response
        return mass * angularFrequency * angularFrequency
    }

    /// Damping coefficient derived from `mass`, `response` and `dampingRatio`: c = 2 * zeta * sqrt(k * m).
    public var damping: Scalar {
        2 * dampingRatio * (stiffness * mass).squareRoot()
    }

    /// Exact analytic solution of the damped harmonic oscillator `x'' + 2*zeta*omega0*x' + omega0^2*x = 0`
    /// (mass cancels out of this reduced form), ported from Android/Jetpack Compose's
    /// `SpringSimulation.updateValues`. Unlike numeric integration this is stable for any `deltaTime`,
    /// however large or small, so no substepping is needed.
    func solve<V: VectorArithmetic>(
        displacement: V, velocity: V, deltaTime: Scalar
    ) -> (displacement: V, velocity: V) where V.Scalar == Scalar {
        let omega0 = 2 * Scalar.pi / response
        let zeta = dampingRatio
        let r = -zeta * omega0
        let t = deltaTime

        if zeta > 1 {
            // Overdamped
            let s = omega0 * (zeta * zeta - 1).squareRoot()
            let gammaPlus = r + s
            let gammaMinus = r - s
            let coeffB = (gammaMinus * displacement - velocity) * (1 / (gammaMinus - gammaPlus))
            let coeffA = displacement - coeffB
            let newDisplacement =
                coeffA * Scalar.exp(gammaMinus * t) + coeffB * Scalar.exp(gammaPlus * t)
            let newVelocity =
                coeffA * gammaMinus * Scalar.exp(gammaMinus * t)
                + coeffB * gammaPlus * Scalar.exp(gammaPlus * t)
            return (newDisplacement, newVelocity)
        } else if zeta == 1 {
            // Critically damped
            let coeffA = displacement
            let coeffB = velocity + omega0 * displacement
            let decay = Scalar.exp(-omega0 * t)
            let newDisplacement = (coeffA + coeffB * t) * decay
            let newVelocity = newDisplacement * -omega0 + coeffB * decay
            return (newDisplacement, newVelocity)
        } else {
            // Underdamped
            let dampedFreq = omega0 * (1 - zeta * zeta).squareRoot()
            let cosCoeff = displacement
            let sinCoeff = (velocity - r * displacement) * (1 / dampedFreq)
            let dFdT = dampedFreq * t
            let decay = Scalar.exp(r * t)
            let newDisplacement =
                decay * (cosCoeff * Scalar.cos(dFdT) + sinCoeff * Scalar.sin(dFdT))
            let newVelocity =
                newDisplacement * r
                + decay
                * (sinCoeff * dampedFreq * Scalar.cos(dFdT) - cosCoeff * dampedFreq
                    * Scalar.sin(dFdT))
            return (newDisplacement, newVelocity)
        }
    }
}

@MainActor
public class SpringAnimator<T: VectorArithmetic> where T.Scalar: RealScalar {
    var simulation: SpringSimulation<T>
    let controller: CompositorAnimationController

    public var configuration: SpringConfiguration<T.Scalar> {
        get { simulation.configuration }
        set { simulation.configuration = newValue }
    }

    /// Approximate settling time in seconds. Lower is snappier/stiffer, higher is looser/softer.
    public var response: T.Scalar {
        get { simulation.configuration.response }
        set { simulation.configuration.response = newValue }
    }

    /// 1 = critically damped (no overshoot), <1 = bouncy, >1 = sluggish.
    public var dampingRatio: T.Scalar {
        get { simulation.configuration.dampingRatio }
        set { simulation.configuration.dampingRatio = newValue }
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
        configuration: SpringConfiguration<T.Scalar> = SpringConfiguration(),
        controller: CompositorAnimationController
    ) {
        self.simulation = SpringSimulation()
        simulation.current = value
        simulation.target = value
        simulation.isFinished = true
        simulation.configuration = configuration

        self.controller = controller
    }

    func animate(to target: T, initialVelocity: T? = nil) {
        if simulation.isFinished {
            controller.add(simulation)
        }
        simulation.target = target
        if let initialVelocity {
            simulation.velocity = initialVelocity
        }
    }
}

/// A mass-spring-damper simulation: m * x'' + c * x' + k * (x - target) = 0, advanced each
/// frame via `SpringConfiguration`'s closed-form solution.
public class SpringSimulation<T: VectorArithmetic>: AnimationFrameUpdatable
where T.Scalar: RealScalar {
    var configuration: SpringConfiguration<T.Scalar> = SpringConfiguration()

    var target: T = .zero {
        didSet {
            isFinished = false
        }
    }
    var current: T = .zero
    var velocity: T = .zero

    var setter: ((T) -> Void)?

    public var isFinished: Bool = true

    public init() {}

    public func update(deltaTime: Duration) {
        guard !isFinished else { return }

        let dt = T.Scalar(deltaTime / .seconds(1))
        guard dt > 0 else { return }

        let motion = configuration.solve(
            displacement: current - target, velocity: velocity, deltaTime: dt)
        current = target + motion.displacement
        velocity = motion.velocity

        if isAtRest {
            current = target
            velocity = .zero
            isFinished = true
        }
    }

    private var isAtRest: Bool {
        abs(current - target).magnitude < configuration.visibilityThreshold
            && abs(velocity).magnitude < configuration.visibilityThreshold / configuration.response
    }
}
