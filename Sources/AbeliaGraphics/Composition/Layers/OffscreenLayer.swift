import ReactivityGraph

class OffscreenLayer: _BaseLayer {
    @Bindable
    public var opacity: Float = 1 {
        didSet { dirtyFlags.insert(.compositionGroup) }
    }


    // effect
    // clip

    // MARK: private
    var offscreenChildren: [_BaseLayer] = []
}

