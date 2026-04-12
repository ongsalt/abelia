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

    var backingStore: RenderTexture?
    var backingStore2: RenderTexture?
    // var attachmentSizeHint: SIMD2<Float>?
}

extension CompositionNode {
    func swapBackingStore() {
        if backingStore2 != nil {
            swap(&backingStore, &backingStore2)
        }
    }

    func toVertexData() -> [CompositeNodeVertexData] {
        let rootSize = rasterizationRoot.size
        let screenSize = SIMD2<UInt32>(
            UInt32(rootSize.x.max(1)),
            UInt32(rootSize.y.max(1))
        )

        let nodePosition = absolutePosition
        let nodeSize = size

        // TODO: layer contents
        let hasContent = contents != nil
        let contentIndex: UInt32 = 0
        // if let renderTexture = contents as? RenderTexture {
        //     contentIndex = renderTexture.index
        // } else {
        //     contentIndex = 0
        // }

        let transform = totalAffine.fastInverse()

        let topLeft = nodePosition
        let bottomLeft = nodePosition + SIMD2(0, nodeSize.y)
        let bottomRight = nodePosition + nodeSize
        let topRight = nodePosition + SIMD2(nodeSize.x, 0)

        let commonArgs = (
            opacity: opacity,
            screenSize: screenSize,
            position: nodePosition,
            size: nodeSize,
            transform: transform,
            cornerRadius: cornerRadius,
            cornerDegree: cornerDegree,
            borderWidth: borderWidth,
            fillColor: fillColor,
            borderColor: borderColor,
            shadowColor: shadowColor,
            shadowOffset: shadowOffset,
            shadowBlur: shadowBlur,
            shadowSpread: shadowSpread,
            hasContent: hasContent,
            contentIndex: contentIndex,
            nineGrid: ninegrid
        )

        return [
            CompositeNodeVertexData(
                opacity: commonArgs.opacity,
                screenSize: commonArgs.screenSize,
                position: commonArgs.position,
                size: commonArgs.size,
                vertexPos: topLeft,
                transform: commonArgs.transform,
                cornerRadius: commonArgs.cornerRadius,
                cornerDegree: commonArgs.cornerDegree,
                borderWidth: commonArgs.borderWidth,
                fillColor: commonArgs.fillColor,
                borderColor: commonArgs.borderColor,
                shadowColor: commonArgs.shadowColor,
                shadowOffset: commonArgs.shadowOffset,
                shadowBlur: commonArgs.shadowBlur,
                shadowSpread: commonArgs.shadowSpread,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid
            ),
            CompositeNodeVertexData(
                opacity: commonArgs.opacity,
                screenSize: commonArgs.screenSize,
                position: commonArgs.position,
                size: commonArgs.size,
                vertexPos: bottomLeft,
                transform: commonArgs.transform,
                cornerRadius: commonArgs.cornerRadius,
                cornerDegree: commonArgs.cornerDegree,
                borderWidth: commonArgs.borderWidth,
                fillColor: commonArgs.fillColor,
                borderColor: commonArgs.borderColor,
                shadowColor: commonArgs.shadowColor,
                shadowOffset: commonArgs.shadowOffset,
                shadowBlur: commonArgs.shadowBlur,
                shadowSpread: commonArgs.shadowSpread,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid
            ),
            CompositeNodeVertexData(
                opacity: commonArgs.opacity,
                screenSize: commonArgs.screenSize,
                position: commonArgs.position,
                size: commonArgs.size,
                vertexPos: bottomRight,
                transform: commonArgs.transform,
                cornerRadius: commonArgs.cornerRadius,
                cornerDegree: commonArgs.cornerDegree,
                borderWidth: commonArgs.borderWidth,
                fillColor: commonArgs.fillColor,
                borderColor: commonArgs.borderColor,
                shadowColor: commonArgs.shadowColor,
                shadowOffset: commonArgs.shadowOffset,
                shadowBlur: commonArgs.shadowBlur,
                shadowSpread: commonArgs.shadowSpread,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid
            ),
            CompositeNodeVertexData(
                opacity: commonArgs.opacity,
                screenSize: commonArgs.screenSize,
                position: commonArgs.position,
                size: commonArgs.size,
                vertexPos: topRight,
                transform: commonArgs.transform,
                cornerRadius: commonArgs.cornerRadius,
                cornerDegree: commonArgs.cornerDegree,
                borderWidth: commonArgs.borderWidth,
                fillColor: commonArgs.fillColor,
                borderColor: commonArgs.borderColor,
                shadowColor: commonArgs.shadowColor,
                shadowOffset: commonArgs.shadowOffset,
                shadowBlur: commonArgs.shadowBlur,
                shadowSpread: commonArgs.shadowSpread,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid
            ),
        ]
    }
}
