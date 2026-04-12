@preconcurrency import CVMA
import Foundation
import Wayland  // for pointers

/// - Main(rect/composite) node
/// - effect node
///
/// - idle : ignore
/// - invalidated -> recomposite from root - rasterizationRoot
/// Commands
/// - recomposite(node) (will delegate to rasterizationRoot)
/// -
/// Deps
/// - children raster layer
/// - sort layer - this can be cache
///     format [.group([Layer]), .effect([EffectLayer])]
///     TODO: early depth testing and culling for opaque layer
///     need to make sure effect layers dont overlap
///     this correspond to 2 Composite pass

// Batch is per rasterization root?
struct Batch {
    let root: CompositionNode
    let hasEffectLayer: Bool  // TODO: (well if we have more than 1 group, we can we need 2 attachment)
    let groups: [Group]

    // we need to put deps in here to? to wait it in render pipeline

    // TODO: better algorithm, currently its just greedy, not minimal Batch group but good enough
    // TODO: write a test for this
    // n^2 lets goooo; n = layer count
    // we can skip rasterizationRoot tho
    init(rootWithChildren: consuming RootWithChildren) {
        root = rootWithChildren.node
        hasEffectLayer = rootWithChildren.hasEffectLayer

        var out: [Group] = []
        var topEffectBatch: [EffectNode] = []
        var topCompositionBatch: [CompositionNode] = []

        for node in rootWithChildren.children {
            if let e = node as? EffectNode {
                if e.overlap(with: topEffectBatch) {
                    // commit and start new batch
                    out.append(.effect(topEffectBatch))
                    topEffectBatch = []
                }
                topEffectBatch.append(e)
            } else if let c = node as? CompositionNode {
                if c.overlap(with: topEffectBatch) {
                    // commit and start new batch
                    out.append(.composite(topCompositionBatch))
                    topCompositionBatch = []
                    out.append(.effect(topEffectBatch))
                    topEffectBatch = []
                }
                topCompositionBatch.append(c)
            }
        }

        if !topCompositionBatch.isEmpty {
            out.append(.composite(consume topCompositionBatch))
        }

        if !topEffectBatch.isEmpty {
            out.append(.effect(consume topEffectBatch))
        }

        groups = out
    }

    static func compute(root: CompositionNode) -> [Batch] {
        let roots = RootWithChildren.group(root)
        return roots.map { Batch(rootWithChildren: $0) }
    }
}

enum Group {
    // basically copy the layer below then draw effect on top of it (by sampling layer below)
    case effect([EffectNode])
    case composite([CompositionNode])

    var isEffect: Bool {
        if case .effect(_) = self {
            return true
        }
        return false
    }
}

extension RenderNode {
    fileprivate func overlap(with other: RenderNode) -> Bool {
        other.absoluteRect.overlap(with: other.absoluteRect)
    }

    fileprivate func overlap(with others: [RenderNode]) -> Bool {
        others.contains { self.overlap(with: $0) }
    }
}

struct RootWithChildren {
    var node: CompositionNode
    var children: [RenderNode]
    var hasEffectLayer: Bool

    // TODO: optimize this
    static func group(_ node: CompositionNode) -> [RootWithChildren] {
        // identify root
        var roots: [CompositionNode] = []
        do {
            func walk(_ node: RenderNode) {
                for c in node.children {
                    walk(c)
                }
                if node.isRasterizationRoot {
                    roots.append(node as! CompositionNode)
                }
            }
            walk(node)
        }

        // for each root find a child
        return roots.map { root in
            var found = false
            var children: [RenderNode] = []
            func walk(_ node: RenderNode) {
                if node.isRasterizationRoot {
                    return
                }
                for c in node.children {
                    children.append(c)
                    found = found || c is EffectNode
                    walk(c)
                }
            }

            walk(root)
            return RootWithChildren(node: root, children: children, hasEffectLayer: found)
        }
    }
}

extension Batch {
    func writeDrawCommands(to cmdBuffer: VkCommandBuffer, inputBuffer: RawGPUBuffer, offset: Int)
        -> Int
    {
        // Transition root.backingStore to attachment optimal layout
        // first backingStore will be expose to other layer, so it will always be use as the output
        let backingStore = root.backingStore!
        var _barriers = [
            VkImageMemoryBarrier2(
                sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
                pNext: nil,
                srcStageMask: VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT,
                srcAccessMask: 0,
                dstStageMask: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
                dstAccessMask: VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
                oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
                newLayout: VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL,
                srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,  // ignore
                dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,  // ignore
                image: backingStore.image,
                subresourceRange: .init(
                    aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                    baseMipLevel: 0,
                    levelCount: 1,
                    baseArrayLayer: 0,
                    layerCount: 1
                )
            )
        ]

        if let b2: RenderTexture = root.backingStore2 {
            _barriers.append(
                VkImageMemoryBarrier2(
                    sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
                    pNext: nil,
                    srcStageMask: VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
                    srcAccessMask: 0,
                    dstStageMask: VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT,
                    dstAccessMask: VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT,
                    oldLayout: VK_IMAGE_LAYOUT_UNDEFINED,
                    newLayout: VK_IMAGE_LAYOUT_ATTACHMENT_OPTIMAL,
                    srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,  // ignore
                    dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,  // ignore
                    image: b2.image,
                    subresourceRange: .init(
                        aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                        baseMipLevel: 0,
                        levelCount: 1,
                        baseArrayLayer: 0,
                        layerCount: 1
                    )
                ),
            )
        }

        let imageBarrier = Pin(_barriers)
        let dependencyInfo = Box(VkDependencyInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO
            $0.imageMemoryBarrierCount = 1
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

            // $0.resolveMode = VK_RESOLVE_MODE_AVERAGE_BIT
            // $0.resolveImageView = imageView
            // $0.resolveImageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }

        let renderingInfo = Box(VkRenderingInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_RENDERING_INFO
            $0.renderArea.extent = SIMD2<UInt32>(root.size).extent2d
            $0.layerCount = 1
            $0.colorAttachmentCount = 1
            $0.pColorAttachments = colorAttachmentInfo.readonly
        }

        // actual rendering
        vkCmdBeginRendering(cmdBuffer, renderingInfo.ptr)
        // write buffer (every group)

        // setViewport
        // bind pipeline
        // vkCmdBindVertexBuffers
        // vkCmdBindIndexBuffer
        // vkCmdPushConstants
        // vkCmdBindDescriptorSets
        //         vkCmdDrawIndexed(commandBuffer, 6, 1, 0, 0, 0)
        // vkCmdEndRendering(commandBuffer)

        // i wont transition image back, if you want to read it, transition it back yourself

    }
}
