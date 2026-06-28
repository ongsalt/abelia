import CShim
import Vulkan

nonisolated(unsafe) private let subresourceRange = ImageSubresourceRange(
    aspectMask: .color, baseMipLevel: 0, levelCount: 1,
    baseArrayLayer: 0, layerCount: 1
)

// just for convenience
struct FrameRenderer {
    let resource: RendererFrameResource
    let registry: TextureRegistry
    let textureCache: TextureCache
    let commandBuffer: CommandBuffer
    let pipelines: Pipelines
    let globalDescriptorSet: DescriptorSet

    func apply(pass: Pass) throws -> (RenderTexture, ImageMemoryBarrier2) {
        // we need to resolve each PassRenderTarget

        // transform child into readable
        // always transform self into .renderTarget

        let texture = try walk(pass)
        let src = RenderTextureState.renderTarget
        let dst = RenderTextureState.transferSource
        let barrier = ImageMemoryBarrier2(
            srcStageMask: src.stageMask, srcAccessMask: src.accessMask,
            dstStageMask: dst.stageMask, dstAccessMask: dst.accessMask,
            oldLayout: src.layout, newLayout: dst.layout, srcQueueFamilyIndex: 0,
            dstQueueFamilyIndex: 0, image: texture.image,
            subresourceRange: subresourceRange
        )

        commandBuffer.pipelineBarrier2()

        return (texture, barrier)
    }

    private func walk(_ pass: borrowing Pass) throws -> RenderTexture {
        // MARK - Barriers

        var barriers: [ImageMemoryBarrier2] = []

        // must walk children before self, cuz .new is leaf node. and we cant do shit without a RenderTexture
        for p in pass.dependencies {
            let texture = try walk(p)
            // if current mode is sameAsPrevious, then this will just be the same state
            // so we are rendering to the same texture.
            if case .sameAsPrevious(let key) = pass.target, key == p.target.key {
                continue
            }

            // for sampling children
            let src = RenderTextureState.renderTarget
            let dst = RenderTextureState.sampling
            barriers.append(
                ImageMemoryBarrier2(
                    srcStageMask: src.stageMask, srcAccessMask: src.accessMask,
                    dstStageMask: dst.stageMask, dstAccessMask: dst.accessMask,
                    oldLayout: src.layout, newLayout: dst.layout, srcQueueFamilyIndex: 0,
                    dstQueueFamilyIndex: 0, image: texture.image,
                    subresourceRange: subresourceRange
                )
            )
            texture.currentLayout = dst.layout
        }

        let targetTexture = try renderTarget(of: pass)

        var src: RenderTextureState
        let dst = RenderTextureState.renderTarget

        if targetTexture.currentLayout == .undefined {
            src = .undefined
        } else if targetTexture.currentLayout == .transferSrcOptimal
            || targetTexture.currentLayout == .presentSrcKHR
        {
            src = .transferSource
        } else if case .sameAsPrevious(_) = pass.target {
            // rendering to the same texture.
            src = .renderTarget
        } else {
            src = RenderTextureState.sampling
        }

        barriers.append(
            ImageMemoryBarrier2(
                srcStageMask: src.stageMask, srcAccessMask: src.accessMask,
                dstStageMask: dst.stageMask, dstAccessMask: dst.accessMask,
                oldLayout: src.layout, newLayout: dst.layout, srcQueueFamilyIndex: 0,
                dstQueueFamilyIndex: 0, image: targetTexture.image,
                subresourceRange: subresourceRange
            )
        )
        targetTexture.currentLayout = dst.layout

        // MARK - renderNode io and command recording
        // TODO: effect, blur pipelines
        switch pass.kind {

        case .composite(let nodes, let useCustomBlend):
            writeMainDrawCommands(
                to: targetTexture,
                nodes,
                useCustomBlend: useCustomBlend,
            )

        case .blur(let regions):
            break
        case .effect(let regions):
            break
        }

        return targetTexture
    }

    private func writeMainDrawCommands(
        to texture: RenderTexture,
        _ nodes: [RenderNode],
        useCustomBlend: Bool,

        // currently unused, might be used with dynamic rendering local read
        beginRendering: Bool = true,
        endRendering: Bool = true,
    ) {
        let firstInstance = resource.drawListStorage.offset
        for node in nodes {
            writeRenderNode(node)
        }
        let renderNodeCount = resource.drawListStorage.offset - firstInstance

        let cmd = commandBuffer
        let size = texture.size

        if beginRendering {
            cmd.beginRendering(
                RenderingInfo(
                    renderArea: .init(
                        offset: .zero, extent: Extent2D(width: size.x, height: size.y)),
                    layerCount: 1,
                    viewMask: 0,
                    colorAttachments: [
                        .init(
                            imageView: texture.view, imageLayout: .colorAttachmentOptimal,
                            resolveMode: .none, resolveImageView: nil,
                            resolveImageLayout: .undefined, loadOp: .clear,
                            storeOp: .store,
                            clearValue: .init(color: .init(float32: (0.0, 0.0, 0.0, 0.0)))
                        )
                    ]
                )
            )
        }

        cmd.bindPipeline(pipelineBindPoint: .graphics, pipeline: pipelines.compositionPipeline)
        cmd.setViewport(
            firstViewport: 0,
            viewports: [
                .init(
                    x: 0,
                    y: 0,
                    width: Float(size.x),
                    height: Float(size.y),
                    minDepth: 0,
                    maxDepth: 1
                )
            ])
        cmd.setScissor(
            firstScissor: 0,
            scissors: [
                .init(offset: .zero, extent: Extent2D(width: size.x, height: size.y))
            ]
        )

        let w = Float(size.x)
        let h = Float(size.y)
        let d: Float = 1000  // perspective depth in pixels; larger = weaker effect
        let projection = Affine().translated(x: -1, y: -1)
            .multiplied(
                by: Affine(
                    col0: SIMD4<Float>(2 / w, 0, 0, 0),
                    col1: SIMD4<Float>(0, 2 / h, 0, 0),
                    col2: SIMD4<Float>(0, 0, 0, 1 / d),  // z bleeds into w → perspective divide
                    col3: SIMD4<Float>(0, 0, 0, 1)
                )
            )
        let viewMatrix = projection
        // let viewport = (size.x, size.y)
        withUnsafeBytes(of: viewMatrix) { viewMatrix in
            cmd.pushConstants(
                layout: pipelines.compositionPipelineLayout,
                stageFlags: [.vertex, .fragment],
                offset: 0,
                size: UInt32(viewMatrix.count),
                values: viewMatrix.baseAddress!
            )
        }

        cmd.bindDescriptorSets(
            pipelineBindPoint: .graphics,
            layout: pipelines.compositionPipelineLayout,
            firstSet: 0,
            descriptorSets: [
                resource.mainDescriptorSet,
                registry.textureDescriptorSet,
                globalDescriptorSet,
            ]
        )

        cmd.draw(
            vertexCount: 6,
            instanceCount: UInt32(renderNodeCount),
            firstVertex: 0,
            firstInstance: UInt32(firstInstance)
        )

        if endRendering {
            cmd.endRendering()
        }
    }

    private func writeRenderNode(_ node: RenderNode) {
        var data = CShim.RenderNode()

        data.affine = node.affine.c
        let instructions = Array(node.shape.drawInstructions)
        if instructions.count <= 1 {
            guard case .push(let metadata) = instructions[0] else {
                fatalError("Invalid shape merging instruction: \(instructions)")
            }

            let (kind, shapeData) = metadata.shape.c
            data.oneOrManyKind = .one_shape
            data.shapeKind = kind
            data.shapeData.one = shapeData
        } else {
            data.oneOrManyKind = .many_shapes
            let startIndex = resource.shapeGroupStorage.offset
            for i in instructions {
                resource.shapeGroupStorage.append(i.c)
            }
            data.shapeData.many = CShim.ManyShapeRef(
                startIndex: UInt32(startIndex), count: UInt32(instructions.count))
        }

        let bounds = node.shape.bounds
        let padding = (node.border?.width ?? 0) + 2
        data.boundMinX = bounds.left - padding
        data.boundMinY = bounds.top - padding
        data.boundMaxX = bounds.right + padding
        data.boundMaxY = bounds.bottom + padding

        (data.brushKind, data.brushData) = node.brush.c

        if let shadow = node.shadow {
            data.shadowOffsetX = shadow.offset.x
            data.shadowOffsetY = shadow.offset.y
            data.shadowBlur = shadow.blur
            data.shadowSpread = shadow.spread
            data.shadowOpacity = shadow.opacity
            let (sr, sg, sb, sa) = shadow.color.linearized.premultiplied.values
            data.shadowColorR = sr
            data.shadowColorG = sg
            data.shadowColorB = sb
            data.shadowColorA = sa
        }

        if let border = node.border {
            data.borderWidth = border.width
            (data.borderBrushKind, data.borderBrushData) = border.brush.c
        }

        resource.renderNodeStorage.append(data)
        let index = resource.renderNodeStorage.offset

        if node.shadow != nil {
            resource.drawListStorage.append(DrawListItem(index: UInt32(index), drawMode: .shadow))
        }
        resource.drawListStorage.append(DrawListItem(index: UInt32(index), drawMode: .fill))
        if node.border != nil {
            resource.drawListStorage.append(DrawListItem(index: UInt32(index), drawMode: .stroke))
        }

    }

    private func renderTarget(of pass: borrowing Pass) throws -> RenderTexture {
        switch pass.target {
        // always a leaf node
        case .new(let size, let key):
            let cachedTexture = textureCache[key]
            // if size also usable
            if let cachedTexture, cachedTexture.main.canResize(to: size) {
                // cachedTexture.main.canResize(to: SIMD2<UInt32>)
                return cachedTexture.main
            } else {
                let tex = try registry.getRenderTexture(size: size)
                textureCache[key] = CompositeGroupTextures(main: tex)
                return tex
            }

        case .alternate(let key):
            // must exist in the cache
            if textureCache[key] == nil {
                fatalError("Invalid pass tree")
            }
            if textureCache[key]!.alternate != nil {
                textureCache[key]!.swap()
                return textureCache[key]!.main
            } else {
                // allocate new if we dont have secondary texture
                let tex = try registry.getRenderTexture(size: textureCache[key]!.main.size)
                textureCache[key]!.swapWithNew(tex)
                return tex
            }

        case .sameAsPrevious(let key):
            guard let cached = textureCache[key] else {
                fatalError("Invalid pass tree")
            }

            return cached.main
        }
    }

}

enum RenderTextureState {
    case undefined
    case renderTarget
    case sampling
    case transferTarget
    case transferSource
}

extension RenderTextureState {
    var layout: ImageLayout {
        switch self {
        case .undefined: .undefined
        case .renderTarget: .attachmentOptimal
        case .sampling: .shaderReadOnlyOptimal
        case .transferTarget: .transferDstOptimal
        case .transferSource: .transferSrcOptimal
        }
    }
    var accessMask: AccessFlags2 {
        switch self {
        case .undefined: .none
        case .renderTarget: [.colorAttachmentWrite, .colorAttachmentRead]
        case .sampling: .shaderRead
        case .transferTarget: .transferWrite
        case .transferSource: .transferRead
        }
    }
    var stageMask: PipelineStageFlags2 {
        switch self {
        case .undefined: .topOfPipe
        case .renderTarget: .colorAttachmentOutput
        case .sampling: .fragmentShader
        case .transferTarget: .allTransfer
        case .transferSource: .allTransfer
        }
    }
}
