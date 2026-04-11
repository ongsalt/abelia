class CompositionNode: RenderNode {
    var cornerRadius: Float = 0
    var cornerDegree: Float = 0

    var shadowColor: Color = .transparent
    var shadowBlur: Float = 0
    var shadowOffset: SIMD2<Float> = .zero
    var shadowSpread: Float = 0

    var borderColor: Color = .transparent
    var borderWidth: Float = 0

    var fillColor: Color = .transparent
    // var scalingMode:

    var contents: LayerContents?
    var ninegrid: SIMD4<Float> = .zero

    // func invalidateContents() {}

    var backingStore: Any?
    // var attachmentSizeHint: SIMD2<Float>?
}
