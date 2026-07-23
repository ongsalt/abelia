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
    }
}
