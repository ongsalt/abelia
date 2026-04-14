class CompositionNode: RenderNode {
    var cornerRadius: Float = 0
    var cornerDegree: Float = 4

    var shadowColor: Color = .transparent
    var shadowBlur: Float = 0
    var shadowOffset: SIMD2<Float> = .zero
    var shadowSpread: Float = 0

    var borderColor: Color = .transparent
    var borderWidth: Float = 0

    var fillColor: Color = .transparent
    var tintColor: Color = .white  // For text tinting
    // var scalingMode:

    var contents: LayerContents?
    var ninegrid: SIMD4<Float> = .zero

    // func invalidateContents() {}

    var backingStore: RenderTexture?
    var backingStore2: RenderTexture?
    // var attachmentSizeHint: SIMD2<Float>?

    // TODO: affine 
    var textureSize: SIMD2<Float> {
        size + 2 * (shadowBlur + shadowSpread)
    }
}

extension CompositionNode {
    func swapBackingStore() {
        if backingStore2 != nil {
            swap(&backingStore, &backingStore2)
        }
    }

    func toVertexData() -> [CompositeNodeVertexData] {
        let rootSize = parent!.rasterizationRoot.size
        let screenSize = SIMD2<UInt32>(
            UInt32(rootSize.x.max(1)),
            UInt32(rootSize.y.max(1))
        )

        let nodePosition = rootRelativePosition
        let nodeSize = size

        let hasContent = contents != nil
        let contentIndex: UInt32 = contents?.renderTexture.index ?? 0

        let transform = totalAffine.inverse()

        let topLeft = totalAffine * nodePosition
        let bottomLeft = totalAffine * (nodePosition + SIMD2(0, nodeSize.y))
        let bottomRight = totalAffine * (nodePosition + nodeSize)
        let topRight = totalAffine * (nodePosition + SIMD2(nodeSize.x, 0))

        let shadowExpand = shadowSpread.max(0) + shadowBlur * 3.0
        let sTopLeft = totalAffine * (nodePosition + shadowOffset - SIMD2(repeating: shadowExpand))
        let sBottomLeft =
            totalAffine
            * (nodePosition + shadowOffset + SIMD2(-shadowExpand, nodeSize.y + shadowExpand))
        let sBottomRight =
            totalAffine * (nodePosition + shadowOffset + nodeSize + SIMD2(repeating: shadowExpand))
        let sTopRight =
            totalAffine
            * (nodePosition + shadowOffset + SIMD2(nodeSize.x + shadowExpand, -shadowExpand))

        let commonArgs = (
            opacity: opacity,
            screenSize: screenSize,
            position: nodePosition,
            size: nodeSize,
            transform: transform,
            cornerRadius: cornerRadius,
            cornerDegree: cornerDegree,
            borderWidth: borderWidth,
            color: fillColor,
            borderColor: borderColor,
            tintColor: tintColor,
            shadowOffset: shadowOffset,
            shadowBlur: shadowBlur,
            shadowSpread: shadowSpread,
            hasContent: hasContent,
            contentIndex: contentIndex,
            nineGrid: ninegrid
        )

        var vertices: [CompositeNodeVertexData] = []

        // 1. Shadow Pass (drawn first, below shape)
        // if isRoot: draw by parent root
        if shadowColor.a > 0 {
            vertices.append(contentsOf: [
                CompositeNodeVertexData(
                    opacity: commonArgs.opacity,
                    screenSize: commonArgs.screenSize,
                    position: commonArgs.position,
                    size: commonArgs.size,
                    vertexPos: sTopLeft,
                    transform: commonArgs.transform,
                    cornerRadius: commonArgs.cornerRadius,
                    cornerDegree: commonArgs.cornerDegree,
                    borderWidth: commonArgs.borderWidth,
                    color: shadowColor,  // Use shadowColor for color field
                    borderColor: .transparent, tintColor: .transparent,
                    shadowOffset: commonArgs.shadowOffset,
                    shadowBlur: commonArgs.shadowBlur,
                    shadowSpread: commonArgs.shadowSpread,
                    hasContent: false,  // Shadows typically don't have content/textures
                    contentIndex: 0,
                    nineGrid: commonArgs.nineGrid,
                    mode: 1.0  // Shadow Mode
                ),
                CompositeNodeVertexData(
                    opacity: commonArgs.opacity,
                    screenSize: commonArgs.screenSize,
                    position: commonArgs.position,
                    size: commonArgs.size,
                    vertexPos: sBottomLeft,
                    transform: commonArgs.transform,
                    cornerRadius: commonArgs.cornerRadius,
                    cornerDegree: commonArgs.cornerDegree,
                    borderWidth: commonArgs.borderWidth,
                    color: shadowColor,
                    borderColor: .transparent,
                    tintColor: .transparent,
                    shadowOffset: commonArgs.shadowOffset,
                    shadowBlur: commonArgs.shadowBlur,
                    shadowSpread: commonArgs.shadowSpread,
                    hasContent: false,
                    contentIndex: 0,
                    nineGrid: commonArgs.nineGrid,
                    mode: 1.0
                ),
                CompositeNodeVertexData(
                    opacity: commonArgs.opacity,
                    screenSize: commonArgs.screenSize,
                    position: commonArgs.position,
                    size: commonArgs.size,
                    vertexPos: sBottomRight,
                    transform: commonArgs.transform,
                    cornerRadius: commonArgs.cornerRadius,
                    cornerDegree: commonArgs.cornerDegree,
                    borderWidth: commonArgs.borderWidth,
                    color: shadowColor,
                    borderColor: .transparent,
                    tintColor: .transparent,
                    shadowOffset: commonArgs.shadowOffset,
                    shadowBlur: commonArgs.shadowBlur,
                    shadowSpread: commonArgs.shadowSpread,
                    hasContent: false,
                    contentIndex: 0,
                    nineGrid: commonArgs.nineGrid,
                    mode: 1.0
                ),
                CompositeNodeVertexData(
                    opacity: commonArgs.opacity,
                    screenSize: commonArgs.screenSize,
                    position: commonArgs.position,
                    size: commonArgs.size,
                    vertexPos: sTopRight,
                    transform: commonArgs.transform,
                    cornerRadius: commonArgs.cornerRadius,
                    cornerDegree: commonArgs.cornerDegree,
                    borderWidth: commonArgs.borderWidth,
                    color: shadowColor,
                    borderColor: .transparent,
                    tintColor: .transparent,
                    shadowOffset: commonArgs.shadowOffset,
                    shadowBlur: commonArgs.shadowBlur,
                    shadowSpread: commonArgs.shadowSpread,
                    hasContent: false,
                    contentIndex: 0,
                    nineGrid: commonArgs.nineGrid,
                    mode: 1.0
                ),
            ])
        }

        // 2. Shape/Content Pass (drawn on top)
        // if isRoot: draw by to self
        vertices.append(contentsOf: [
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
                color: fillColor,  // Normal fill color
                borderColor: commonArgs.borderColor, tintColor: commonArgs.tintColor,
                shadowOffset: .zero,
                shadowBlur: 0,
                shadowSpread: 0,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid,
                mode: 0.0  // Shape Mode
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
                color: fillColor,
                borderColor: commonArgs.borderColor,
                tintColor: commonArgs.tintColor,
                shadowOffset: .zero,
                shadowBlur: 0,
                shadowSpread: 0,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid,
                mode: 0.0
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
                color: fillColor,
                borderColor: commonArgs.borderColor,
                tintColor: commonArgs.tintColor,
                shadowOffset: .zero,
                shadowBlur: 0,
                shadowSpread: 0,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid,
                mode: 0.0
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
                color: fillColor,
                borderColor: commonArgs.borderColor,
                tintColor: commonArgs.tintColor,
                shadowOffset: .zero,
                shadowBlur: 0,
                shadowSpread: 0,
                hasContent: commonArgs.hasContent,
                contentIndex: commonArgs.contentIndex,
                nineGrid: commonArgs.nineGrid,
                mode: 0.0
            ),
        ])

        // 3. Composite pass
        // TODO: calculate optimal size in case of overflow
        // children position must be absolute to this
        // if isRasterizationRoot {
        //     vertices.append(contentsOf: [
        //         CompositeNodeVertexData(
        //             opacity: commonArgs.opacity,
        //             screenSize: commonArgs.screenSize,
        //             position: commonArgs.position,
        //             size: commonArgs.size,
        //             vertexPos: topLeft,
        //             transform: commonArgs.transform,
        //             cornerRadius: commonArgs.cornerRadius,
        //             cornerDegree: commonArgs.cornerDegree,
        //             borderWidth: commonArgs.borderWidth,
        //             color: fillColor,  // Normal fill color
        //             borderColor: commonArgs.borderColor, tintColor: commonArgs.tintColor,
        //             shadowOffset: .zero,
        //             shadowBlur: 0,
        //             shadowSpread: 0,
        //             hasContent: commonArgs.hasContent,
        //             contentIndex: commonArgs.contentIndex,
        //             nineGrid: commonArgs.nineGrid,
        //             mode: 0.0  // Shape Mode
        //         ),
        //         CompositeNodeVertexData(
        //             opacity: commonArgs.opacity,
        //             screenSize: commonArgs.screenSize,
        //             position: commonArgs.position,
        //             size: commonArgs.size,
        //             vertexPos: bottomLeft,
        //             transform: commonArgs.transform,
        //             cornerRadius: commonArgs.cornerRadius,
        //             cornerDegree: commonArgs.cornerDegree,
        //             borderWidth: commonArgs.borderWidth,
        //             color: fillColor,
        //             borderColor: commonArgs.borderColor,
        //             tintColor: commonArgs.tintColor,
        //             shadowOffset: .zero,
        //             shadowBlur: 0,
        //             shadowSpread: 0,
        //             hasContent: commonArgs.hasContent,
        //             contentIndex: commonArgs.contentIndex,
        //             nineGrid: commonArgs.nineGrid,
        //             mode: 0.0
        //         ),
        //         CompositeNodeVertexData(
        //             opacity: commonArgs.opacity,
        //             screenSize: commonArgs.screenSize,
        //             position: commonArgs.position,
        //             size: commonArgs.size,
        //             vertexPos: bottomRight,
        //             transform: commonArgs.transform,
        //             cornerRadius: commonArgs.cornerRadius,
        //             cornerDegree: commonArgs.cornerDegree,
        //             borderWidth: commonArgs.borderWidth,
        //             color: fillColor,
        //             borderColor: commonArgs.borderColor,
        //             tintColor: commonArgs.tintColor,
        //             shadowOffset: .zero,
        //             shadowBlur: 0,
        //             shadowSpread: 0,
        //             hasContent: commonArgs.hasContent,
        //             contentIndex: commonArgs.contentIndex,
        //             nineGrid: commonArgs.nineGrid,
        //             mode: 0.0
        //         ),
        //         CompositeNodeVertexData(
        //             opacity: commonArgs.opacity,
        //             screenSize: commonArgs.screenSize,
        //             position: commonArgs.position,
        //             size: commonArgs.size,
        //             vertexPos: topRight,
        //             transform: commonArgs.transform,
        //             cornerRadius: commonArgs.cornerRadius,
        //             cornerDegree: commonArgs.cornerDegree,
        //             borderWidth: commonArgs.borderWidth,
        //             color: fillColor,
        //             borderColor: commonArgs.borderColor,
        //             tintColor: commonArgs.tintColor,
        //             shadowOffset: .zero,
        //             shadowBlur: 0,
        //             shadowSpread: 0,
        //             hasContent: commonArgs.hasContent,
        //             contentIndex: commonArgs.contentIndex,
        //             nineGrid: commonArgs.nineGrid,
        //             mode: 0.0
        //         ),
        //     ])

        // }

        return vertices
    }

}
