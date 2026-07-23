import ReactivityGraph

public class OffscreenLayer: Layer {

    // effect
    // clip

    // MARK: private
    var offscreenChildren: [_BaseLayer] = []

    override init() {
        super.init()
        accumulatedOpacity = Computed { 1.0 }
        effectiveOpacity = Computed { [unowned self] in
            (parent?.accumulatedOpacity.value ?? 1.0) * self.opacity
        }

        self.accumulatedTransform = Computed { .identity }
        self.effectiveTransform = Computed { [unowned self] in
            let o = transformOrigin * size
            let d = (0.5 - anchor) * size

            return (parent?.accumulatedTransform.value ?? .identity)
                .translated(x: offset.x, y: offset.y, z: offset.z)
                .translated(x: o.x, y: o.y)
                .multiplied(by: affine)
                .rotated(rotation, axis: rotationAxis)
                .scaled(x: scale.x, y: scale.y)
                .translated(x: -o.x, y: -o.y)
                .translated(x: d.x, y: d.y)
        }
    }
}
