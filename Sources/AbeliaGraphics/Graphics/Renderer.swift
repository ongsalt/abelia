/// store node index

import CShim
import Vulkan

nonisolated(unsafe) let subresourceRange = ImageSubresourceRange(
    aspectMask: .color, baseMipLevel: 0, levelCount: 1,
    baseArrayLayer: 0, layerCount: 1
)

struct Renderer {
    let context: DeviceContext
    let releaseQueue: ReleaseQueue

    let globalDescriptorSet: DescriptorSet
    fileprivate let pipelines: Pipelines
    let textureRegistry: TextureRegistry
    let textureCache: TextureCache = TextureCache()

    private var frameResources: [RendererFrameResource]
    private var frameInFlightCount: Int
    private var currentFrameInFlight = 0
}

extension Renderer {
    var resource: RendererFrameResource {
        frameResources[currentFrameInFlight]
    }

    init(context: DeviceContext, frameInFlightCount: Int) throws(Vulkan.Result) {
        let pipelines = try Pipelines(
            format: .b8g8r8a8Srgb,
            context: context,
            frameInFlightCount: frameInFlightCount
        )
        let releaseQueue = ReleaseQueue()
        let textureDescriptorSet = try pipelines.createTextureDescriptorSet(context)
        let textureRegistry = TextureRegistry(
            textureDescriptorSet, releaseQueue: releaseQueue, context: context)

        let frameResources = try (0..<frameInFlightCount).map { i throws(Vulkan.Result) in
            try RendererFrameResource(index: i, context: context, pipelines: pipelines)
        }

        self.init(
            context: context,
            releaseQueue: releaseQueue,
            globalDescriptorSet: try pipelines.createSamplerDescriptorSet(context),
            pipelines: pipelines,
            textureRegistry: textureRegistry,
            frameResources: frameResources,
            frameInFlightCount: frameInFlightCount,
        )
    }

    // you need to wait it yourself
    // TODO: stop resolving this, but do it in shader to map color back
    mutating func render(
        _ pass: Pass,
        in commandBuffer: CommandBuffer,
        incrementFrameCounter: Bool = true
    )
        throws(Vulkan.Result) -> RenderTexture
    {
        resource.drawListStorage.resetOffset()
        resource.renderNodeStorage.resetOffset()
        resource.shapeGroupStorage.resetOffset()
        resource.polygonVertexStorage.resetOffset()

        let texture = try walk(pass, commandBuffer)

        // resource.renderNodeStorage.dump()
        // resource.shapeGroupStorage.dump()
        // resource.drawListStorage.dump()
        // textureRegistry.dump()

        if incrementFrameCounter {
            self.incrementFrameCounter()
        }
        return texture
    }

    mutating func incrementFrameCounter() {
        currentFrameInFlight = (currentFrameInFlight + 1) % self.frameInFlightCount
    }

    mutating func updateFrameInFlightCount(_ count: Int) {
        let prev = frameInFlightCount
        if count > prev {
            for i in prev..<count {
                frameResources.append(
                    try! RendererFrameResource(
                        index: i, context: context, pipelines: self.pipelines))
            }
        }

        self.frameInFlightCount = count
    }

    private func walk(
        _ pass: borrowing Pass,
        _ commandBuffer: CommandBuffer,
        overridedImageView: ImageView? = nil
    ) throws(Vulkan.Result)
        -> RenderTexture
    {
        // MARK - Barriers

        var barriers: [ImageMemoryBarrier2] = []

        // must walk children before self, cuz .new is leaf node. and we cant do shit without a RenderTexture
        for p in pass.dependencies {
            let texture = try walk(p, commandBuffer)
            // if current mode is sameAsPrevious, then this will just be the same state
            // so we are rendering to the same texture.
            if case .sameAsPrevious(let key) = pass.target, key == p.target.key {
                continue
            }

            // for sampling children
            var src = RenderTextureState.renderTarget
            if texture.currentLayout == .undefined {
                src = .undefined
            }
            let dst = RenderTextureState.sampling
            // Log.debug(
            //     .renderer,
            //     "barriers: add [\(texture.index)](\(texture.currentLayout)) \(src) -> \(dst)")
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
        } else if case .sameAsPrevious = pass.target {
            // rendering to the same texture.
            src = .renderTarget
        } else if targetTexture.currentLayout == .attachmentOptimal {
            src = .renderTarget
        } else {
            src = RenderTextureState.sampling
        }

        // Log.debug(
        //     .renderer,
        //     "barriers: add (root) [\(targetTexture.index)](\(targetTexture.currentLayout)) \(src) -> \(dst)"
        // )

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

        commandBuffer.pipelineBarrier2(
            DependencyInfo(imageMemoryBarriers: barriers)
        )
        // Log.debug(.renderer, "barriers: wait \(barriers.count) barriers")

        // MARK - renderNode io and command recording
        // TODO: effect, blur pipelines
        switch pass.kind {

        case .composite(let nodes, let useCustomBlend):
            render(
                nodes: nodes,
                to: targetTexture,
                overridedImageView: overridedImageView,
                useCustomBlend: useCustomBlend,
                in: commandBuffer
            )

        case .blur(let regions):
            break
        case .effect(let regions):
            break
        }

        return targetTexture
    }

    private func render(
        nodes: [RenderNode],
        to texture: RenderTexture,
        overridedImageView: ImageView? = nil,
        useCustomBlend: Bool,
        in commandBuffer: CommandBuffer,

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
        let size = texture.size  // TODO: get overridedImageView size
        let view = overridedImageView ?? texture.view
        Log.verbose(
            .renderer,
            "drawing: size=\(size), nodes.count=\(nodes.count), useCustomBlend=\(useCustomBlend), into=\(view.handle!)"
        )
        Log.verbose(.renderer, "firstInstance=\(firstInstance), renderNodeCount=\(renderNodeCount)")

        if beginRendering {
            cmd.beginRendering(
                RenderingInfo(
                    renderArea: .init(
                        offset: .zero, extent: Extent2D(width: size.x, height: size.y)),
                    layerCount: 1,
                    viewMask: 0,
                    colorAttachments: [
                        .init(
                            imageView: view,
                            imageLayout: .colorAttachmentOptimal,
                            resolveMode: .none,
                            resolveImageView: nil,
                            resolveImageLayout: .undefined,
                            loadOp: .clear,
                            storeOp: .store,
                            clearValue: .init(color: .init(float32: (0.0, 0.0, 0.0, 0.0)))
                        )
                    ],
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
        // Log.debug(.renderer, "\(w)x\(h)")
        // Log.debug(.renderer, "\(viewMatrix)")
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
                textureRegistry.textureDescriptorSet,
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

    private func writeRenderNode(_ node: consuming RenderNode) {
        resolveBackdropBrush(for: &node)

        var data = CShim.RenderNode()

        data.affine = node.affine.c
        let instructions = Array(node.shape.drawInstructions)
        let startIndex = resource.shapeGroupStorage.offset
        for i in instructions {
            resource.shapeGroupStorage.append(appendingPolygonVertices(i))
        }
        data.shapeStartIndex = UInt32(startIndex)
        data.shapeCount = UInt32(instructions.count)

        let bounds = node.shape.bounds
        let padding = node.border?.width ?? 0
        data.boundMinX = bounds.left - padding
        data.boundMinY = bounds.top - padding
        data.boundMaxX = bounds.right + padding
        data.boundMaxY = bounds.bottom + padding

        (data.brushKind, data.brushData) = node.brush.c
        data.opacity = node.opacity

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

        let index = resource.renderNodeStorage.append(data)

        if node.shadow != nil {
            resource.drawListStorage.append(DrawListItem(index: UInt32(index), drawMode: .shadow))
        }
        resource.drawListStorage.append(DrawListItem(index: UInt32(index), drawMode: .fill))
        if node.border != nil {
            resource.drawListStorage.append(DrawListItem(index: UInt32(index), drawMode: .stroke))
        }

    }

    // Polygon vertices live in a dedicated buffer; write them and patch the shape's startIndex
    // (Shape.c can't know the buffer offset). Non-polygon instructions pass straight through.
    private func appendingPolygonVertices(_ instruction: ShapeMergingInstruction)
        -> CShim.ShapeMergingEntry
    {
        guard case .push(let meta) = instruction,
            case .polygon(let vertices, let perimeterOffset) = meta.shape
        else {
            return instruction.c
        }

        let start = resource.polygonVertexStorage.offset
        for v in vertices {
            resource.polygonVertexStorage.append(v)
        }

        var shape = CShim.Shape()
        shape.polygon = CShim.Polygon(
            startIndex: UInt32(start),
            count: UInt32(vertices.count),
            perimeterOffset: perimeterOffset
        )
        var entry = CShim.ShapeMergingEntry()
        entry.kind = .push
        entry.data.shape = CShim.ShapeMetadata(
            shapeKind: .polygon, shape: shape, offset: (meta.offset.x, meta.offset.y))
        return entry
    }

    private func resolveBackdropBrush(for node: inout RenderNode) {
        if case .backdrop(let key, let c) = node.brush {
            let texture = textureCache[key]!
            let index = texture.main.index
            let mul = texture.main.croppedSizeMultiplier
            let crop = Rect(
                top: c.top * mul.y,
                left: c.left * mul.x,
                width: c.width * mul.x,
                height: c.height * mul.y
            )
            // we need to crop again cuz actual texture can be larger than logical size
            node.brush = .texture(index: index, crop: crop)
            Log.verbose(.renderer, "Resolved backdrop brush index:\(index) for key:\(key)")
        }
    }

    private func renderTarget(of pass: borrowing Pass) throws(Vulkan.Result) -> RenderTexture {
        switch pass.target {
        // always a leaf node
        case .new(let size, let key, let canTransfer):
            let cachedTexture = textureCache[key]
            // if size also usable
            if let cachedTexture {
                if cachedTexture.main.canResize(to: size) {
                    cachedTexture.main.resize(to: size)
                    return cachedTexture.main
                } else {
                    cachedTexture.main.recycle()
                    cachedTexture.alternate?.recycle()
                }
            }

            let tex = try textureRegistry.getRenderTexture(size: size, canTransfer: canTransfer)
            textureCache[key] = CompositeGroupTextures(main: tex)
            return tex

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
                let tex = try textureRegistry.getRenderTexture(size: textureCache[key]!.main.size)
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

// this should be per frame context
struct RendererFrameResource {
    let mainDescriptorSet: DescriptorSet
    let renderNodeStorage: RenderNodeBuffer
    let shapeGroupStorage: ShapeBuffer
    let drawListStorage: DrawListBuffer
    let polygonVertexStorage: PolygonVertexBuffer

    fileprivate init(index: Int, context: borrowing DeviceContext, pipelines: borrowing Pipelines)
        throws(Vulkan.Result)
    {
        let mainDescriptorSet = try pipelines.createMainDescriptorSet(context)
        let renderNodeStorage = try RenderNodeBuffer(context: context)
        let shapeGroupStorage = try ShapeBuffer(context: context)
        let drawListStorage = try DrawListBuffer(context: context)
        let polygonVertexStorage = try PolygonVertexBuffer(context: context)

        context.device.updateDescriptorSets(descriptorWrites: [
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 0,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: renderNodeStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 1,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: shapeGroupStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 2,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: drawListStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),
            .init(
                dstSet: mainDescriptorSet,
                dstBinding: 5,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: .storageBuffer,
                imageInfo: [],
                bufferInfo: [
                    .init(buffer: polygonVertexStorage.buffer, offset: 0, range: VK_WHOLE_SIZE)
                ],
                texelBufferView: []
            ),

        ])

        self.mainDescriptorSet = mainDescriptorSet
        self.renderNodeStorage = renderNodeStorage
        self.shapeGroupStorage = shapeGroupStorage
        self.drawListStorage = drawListStorage
        self.polygonVertexStorage = polygonVertexStorage
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
