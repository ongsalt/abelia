@preconcurrency import CVulkan
import Foundation
import Pointer  // for pointers

@MainActor
public class Compositor: @unchecked Sendable {
    let state: VulkanState
    let pipeline: CompositePipeline
    let inputBuffer: InputBuffer  // this should be per frame in flight

    let renderer: Renderer
    let textureRegistry: RenderTextureRegistry
    let textRenderer = TextRenderer()
    var size: SIMD2<UInt32>

    var animationFrameControllers: [ObjectIdentifier: AnimationFrameController] = [:]
    let root: CompositionNode
    private let dirtyNotifier = DirtyNotifier()
    private(set) var isRecording = false

    // use the root layer with caution, some property should not be touch
    // private let frameClock = FrameClock()

    // TODO: frame sync, proper sending, most of the task is synchronous except waiting for frame

    init(state: VulkanState) {
        self.state = state
        self.size = state.swapChain.extent.simd2

        self.root = CompositionNode()
        self.root.shouldRasterize = true  // we should force this somehow
        self.root.size = SIMD2(self.size)
        self.root.parent = dirtyNotifier

        self.textureRegistry = RenderTextureRegistry(vulkan: state)
        self.renderer = Renderer(state: state, textureRegistry: textureRegistry)

        self.inputBuffer = InputBuffer(state: state)
        self.pipeline = CompositePipeline(state: state, textureRegistry: textureRegistry)

        // should i just remove this and make everthing tell the compositor directly
        dirtyNotifier.onDirty = { [] in
            // recompositionQueue.schedule()
        }

        self.root.compositor = self
    }

    func start() -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                // wait until dirty
                let continuousClock: ContinuousClock = ContinuousClock()
                let start = continuousClock.now
                // Log.info(.compositor, "Recomposition start")
                await self.recomposite()
                let end = continuousClock.now
            }
        }
    }

    private func recomposite() async {
        inputBuffer.reset()
        for controller in animationFrameControllers.values {
            controller.run()
        }
        // just redraw everything ... rasterizationRoot
        let batches = Batch.compute(root: root)

        // allocate backing store
        for batch in batches {
            var n = 0
            let root = batch.root
            let size: SIMD2<UInt32> = [UInt32(root.size.x), UInt32(root.size.y)]
            if size == .zero {
                continue
            }
            if root.backingStore == nil {
                n += 1
                let t = textureRegistry.newRenderTarget(size: size)
                root.backingStore = t
            }
            if batch.hasEffectLayer && root.backingStore2 == nil {
                n += 1
                let t = textureRegistry.newRenderTarget(size: size)
                root.backingStore2 = t
            }

            if n > 0 {
                Log.debug(
                    .compositor,
                    "allocated \(n) backing store for CompositeNode \(batch.root.backingStore?.image)"
                )
            }
        }

        // TODO: fix race condition
        root.markClean()

        // Log.debug(.compositor, "\(root.backingStore?.image)")
        // present it somehow

        await renderer.perform { commandBuffer, swapChainImageView in
            Log.info(.renderLoop, "acquired frame")
            // is this counted as multithread recording

            // need to group this to phase
            for batch in batches {
                let iv: VkImageView? =
                    if batch.root.id == self.root.id {
                        swapChainImageView
                    } else {
                        nil
                    }
                writeDrawCommands(
                    to: commandBuffer,
                    batch: batch,
                    inputBuffer: inputBuffer,
                    pipeline: pipeline,
                    swapChainImageView: iv,
                    textureRegistry: textureRegistry
                )
            }
        }
    }

    public func requestAnimationFrame(callback: @escaping (AnimationFrameController) -> Void) {
        let controller = AnimationFrameController(callback, self)
        self.animationFrameControllers[controller.id] = controller
    }

}

@MainActor
private class DirtyNotifier: RenderNode {
    var onDirty: () -> Void = {}
    override var dirty: Bool {
        didSet {
            if dirty {
                onDirty()
            }
        }
    }

    override init() {
        super.init()
        self.dirty = false
    }
}

@MainActor
private func writeDrawCommands(
    to cmdBuffer: VkCommandBuffer,
    batch: Batch,
    inputBuffer: InputBuffer,
    pipeline: CompositePipeline,
    swapChainImageView: VkImageView? = nil,
    textureRegistry: RenderTextureRegistry
) {
    if batch.groups.isEmpty {
        return
    }
    // Log.debug(.compositor, "Writing draw command for \(batch)")

    let backingStore = batch.root.backingStore!
    let size = SIMD2<UInt32>(batch.root.size)

    if !batch.dependencies.isEmpty {
        Log.debug(.compositor, "added barriers for deps \(batch.dependencies)")
        // Barrier for layer depemdencies, prepare for sampling
        // what if i over transition
        var _barriers: [VkImageMemoryBarrier2] = []
        for dep in batch.dependencies {
            if let depBackingStore = dep.backingStore {
                _barriers.append(
                    depBackingStore.barrier(
                        to: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                        stageMask: VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT,
                        accessMask: VK_ACCESS_2_SHADER_SAMPLED_READ_BIT)
                )
            }
        }
        let imageBarrier = Pin(_barriers)
        let dependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = UInt32(imageBarrier.count)
            $0.pImageMemoryBarriers = imageBarrier.readonly
        }
        vkCmdPipelineBarrier2(cmdBuffer, dependencyInfo.ptr)
    }

    // actually drawing it
    for group: Group in batch.groups {
        // Transition root.backingStore to attachment optimal layout
        // first backingStore will be expose to other layer, so it will always be use as the output
        batch.root.swapBackingStore()
        // i wont transition image back, if you want to read it, transition it back yourself

        // texture
        // 1 -> write to first store
        // 2 -> write to first store, read from second
        // external: read from first
        Log.debug(.compositor, "placed barrier for \(backingStore.image)")
        var _barriers: [VkImageMemoryBarrier2] = [
            backingStore.barrier(
                to: VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL,
                stageMask: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
                accessMask: VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT
                    | VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT
            )
        ]

        if let b2: RenderTexture = batch.root.backingStore2 {
            _barriers.append(
                b2.barrier(
                    to: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    stageMask: VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT,
                    accessMask: VK_ACCESS_2_SHADER_SAMPLED_READ_BIT
                ),
            )
        }

        let imageBarrier = Pin(_barriers)
        let dependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = UInt32(imageBarrier.count)
            $0.pImageMemoryBarriers = imageBarrier.readonly
        }
        vkCmdPipelineBarrier2(cmdBuffer, dependencyInfo.ptr)

        // Setup rendering attachment
        let colorAttachmentInfo = Box(VkRenderingAttachmentInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO
            $0.imageView = backingStore.view
            $0.imageLayout = VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL
            $0.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
            $0.storeOp = VK_ATTACHMENT_STORE_OP_STORE
            $0.clearValue.color.float32 = (0.0, 0.0, 0.0, 0.0)

            if let swapChainImageView {
                // Log.debug(.compositor, "has swapChainImageView: \(swapChainImageView)")

                $0.resolveMode = VK_RESOLVE_MODE_AVERAGE_BIT
                $0.resolveImageView = swapChainImageView
                $0.resolveImageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
            }
        }

        let renderingInfo = Box(VkRenderingInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_RENDERING_INFO
            $0.renderArea.extent = size.extent2d
            $0.layerCount = 1
            $0.colorAttachmentCount = 1
            $0.pColorAttachments = colorAttachmentInfo.readonly
        }

        // actual rendering
        vkCmdBeginRendering(cmdBuffer, renderingInfo.ptr)
        // write buffer (every group)

        setViewport(size, commandBuffer: cmdBuffer)

        // bind pipeline
        switch group {
        // TODO:
        case .composite(let nodes):
            pipeline.bind(commandBuffer: cmdBuffer)  // its composition pipeline

            let vertexData: [CompositeNodeVertexData] = nodes.flatMap { $0.toVertexData() }
            Log.debug(.compositor, "vertexData hash = \(vertexData.hashValue)")

            let quadCount = vertexData.count / 4
            let indices = (0..<quadCount).flatMap { i -> [UInt32] in
                let o = UInt32(i) * 4
                return [o, o + 1, o + 2, o, o + 3, o + 2]
            }

            var pos = inputBuffer.write(vertexData)
            let pos2 = inputBuffer.write(indices)

            vkCmdBindVertexBuffers(cmdBuffer, 0, 1, &inputBuffer.raw.buffer, &pos)
            vkCmdBindIndexBuffer(cmdBuffer, inputBuffer.raw.buffer, pos2, VK_INDEX_TYPE_UINT32)

            var address: SIMD2<UInt32> = [800, 600]
            vkCmdPushConstants(
                cmdBuffer,
                pipeline.pipelineLayout,
                VK_SHADER_STAGE_VERTEX_BIT.rawValue | VK_SHADER_STAGE_FRAGMENT_BIT.rawValue,
                0,
                UInt32(MemoryLayout<SIMD2<UInt32>>.size),
                &address
            )

            var descriptorSet: VkDescriptorSet? = textureRegistry.descriptorSet
            vkCmdBindDescriptorSets(
                cmdBuffer,
                VK_PIPELINE_BIND_POINT_GRAPHICS,
                pipeline.pipelineLayout,
                0,
                1,
                &descriptorSet,
                0,
                nil
            )

            vkCmdDrawIndexed(cmdBuffer, UInt32(indices.count), 1, 0, 0, 0)
            Log.debug(.compositor, "drawing \(indices.count) indices")
        case .effect(let nodes):
            Log.debug(.compositor, "ignoring effect group: \(nodes)")

        }

        vkCmdEndRendering(cmdBuffer)
    }

    Log.debug(.compositor, "Done")
}

private func setViewport(_ size: SIMD2<UInt32>, commandBuffer: VkCommandBuffer) {
    var viewport = VkViewport(
        x: 0,
        y: 0,
        width: Float(size.x),
        height: Float(size.y),
        minDepth: 0.0,
        maxDepth: 1.0
    )
    vkCmdSetViewport(commandBuffer, 0, 1, &viewport)

    var scissor = VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: .init(width: size.x, height: size.y)
    )
    vkCmdSetScissor(commandBuffer, 0, 1, &scissor)
}
