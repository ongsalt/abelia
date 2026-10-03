// stolen from jetpack compose

public struct SpringConfiguration {
    public var mass: Float
    /// Approximate settling time in seconds. Lower is snappier/stiffer, higher is looser/softer.
    public var response: Float
    /// 1 = critically damped (no overshoot), <1 = bouncy, >1 = sluggish.
    public var dampingRatio: Float
    /// Distance from target (in the animated value's own units) below which the spring is
    /// considered at rest. The matching velocity cutoff is derived from this and `response`.
    public var visibilityThreshold: Float

    public init(
        mass: Float = 1, response: Float = 0.45, dampingRatio: Float = 1,
        visibilityThreshold: Float = 0.01
    ) {
        self.mass = mass
        self.response = response
        self.dampingRatio = dampingRatio
        self.visibilityThreshold = visibilityThreshold
    }

    /// Spring constant derived from `mass` and `response`: k = m * (2pi / response)^2.
    public var stiffness: Float {
        let angularFrequency = 2 * Float.pi / response
        return mass * angularFrequency * angularFrequency
    }

    /// Damping coefficient derived from `mass`, `response` and `dampingRatio`: c = 2 * zeta * sqrt(k * m).
    public var damping: Float {
        2 * dampingRatio * (stiffness * mass).squareRoot()
    }
}

@MainActor
public class SpringAnimator<T: VectorArithmetic> {
    var simulation: SpringSimulation<T>
    let controller: CompositorAnimationController

    public var configuration: SpringConfiguration {
        get { simulation.configuration }
        set { simulation.configuration = newValue }
    }

    /// Approximate settling time in seconds. Lower is snappier/stiffer, higher is looser/softer.
    public var response: Float {
        get { simulation.configuration.response }
        set { simulation.configuration.response = newValue }
    }

    /// 1 = critically damped (no overshoot), <1 = bouncy, >1 = sluggish.
    public var dampingRatio: Float {
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
        configuration: SpringConfiguration = SpringConfiguration(),
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
public class SpringSimulation<T: VectorArithmetic>: AnimationFrameUpdatable {
    var configuration: SpringConfiguration = SpringConfiguration()

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

        let motion = solve(
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
        (current - target).length < T.Scalar(configuration.visibilityThreshold)
            && velocity.length
                < T.Scalar(configuration.visibilityThreshold / configuration.response)
    }

    /// Exact analytic solution of the damped harmonic oscillator `x'' + 2*zeta*omega0*x' + omega0^2*x = 0`
    /// (mass cancels out of this reduced form), ported from Android/Jetpack Compose's
    /// `SpringSimulation.updateValues`. Unlike numeric integration this is stable for any `deltaTime`,
    /// however large or small, so no substepping is needed.
    func solve(
        displacement: T,
        velocity: T,
        deltaTime: T.Scalar
    ) -> (displacement: T, velocity: T) {
        let omega0 = 2 * T.Scalar.pi / T.Scalar(configuration.response)
        let zeta = T.Scalar(configuration.dampingRatio)
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
                coeffA * T.Scalar.exp(gammaMinus * t) + coeffB * T.Scalar.exp(gammaPlus * t)
            let newVelocity =
                coeffA * gammaMinus * T.Scalar.exp(gammaMinus * t)
                + coeffB * gammaPlus * T.Scalar.exp(gammaPlus * t)
            return (newDisplacement, newVelocity)
        } else if zeta == 1 {
            // Critically damped
            let coeffA = displacement
            let coeffB = velocity + omega0 * displacement
            let decay = T.Scalar.exp(-omega0 * t)
            let newDisplacement = (coeffA + coeffB * t) * decay
            let newVelocity = newDisplacement * -omega0 + coeffB * decay
            return (newDisplacement, newVelocity)
        } else {
            // Underdamped
            let dampedFreq = omega0 * (1 - zeta * zeta).squareRoot()
            let cosCoeff = displacement
            let sinCoeff = (velocity - r * displacement) * (1 / dampedFreq)
            let dFdT = dampedFreq * t
            let decay = T.Scalar.exp(r * t)
            let newDisplacement =
                decay * (cosCoeff * T.Scalar.cos(dFdT) + sinCoeff * T.Scalar.sin(dFdT))
            let newVelocity =
                newDisplacement * r
                + decay
                * (sinCoeff * dampedFreq * T.Scalar.cos(dFdT) - cosCoeff * dampedFreq
                    * T.Scalar.sin(dFdT))
            return (newDisplacement, newVelocity)
        }
    }
}
