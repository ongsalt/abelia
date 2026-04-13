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
// we then can pararellize this by running phase 1 of every batch simulteneously unless its depends on each other
//  - need to do per group deps not per batch

struct Batch {
    let root: CompositionNode
    let hasEffectLayer: Bool  // TODO: (well if we have more than 1 group, we can we need 2 attachment)
    let groups: [Group]

    let depth: Int
    let dependencies: [CompositionNode]

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

        var dependencies: [CompositionNode] = []

        for node in rootWithChildren.children {
            if let e = node as? EffectNode {
                if e.overlap(with: topEffectBatch) {
                    // commit and start new batch
                    out.append(.effect(topEffectBatch))
                    topEffectBatch = []
                }
                topEffectBatch.append(e)
            } else if let c = node as? CompositionNode {
                if c.isRasterizationRoot {
                    dependencies.append(c)
                }
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
        self.dependencies = dependencies
        self.depth = rootWithChildren.depth
    }

    static func compute(root: CompositionNode) -> [Batch] {
        let roots = RootWithChildren.group(root)
        return roots.map { Batch(rootWithChildren: $0) }
    }

    static func run(batches: [Batch]) {
        var batchesByDepth: [[Batch]] = []
        // lowest depth: batches with no deps
        batchesByDepth.append(batches.filter { $0.dependencies.isEmpty })

        // next is batch that only depends on lower level batch

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
    var depth: Int

    // TODO: optimize this
    static func group(_ node: CompositionNode) -> [RootWithChildren] {
        // identify root
        // var roots: [CompositionNode] = []
        var roots: [RootWithChildren] = []
        var currentRoot: RootWithChildren? = nil
        func walk(_ node: RenderNode) {
            // add self to current root
            currentRoot?.children.append(node)

            if node is EffectNode {
                currentRoot?.hasEffectLayer = true
            }

            let prev = currentRoot
            // set self as current root
            if node.isRasterizationRoot {
                currentRoot = RootWithChildren(
                    node: node as! CompositionNode,
                    children: [],
                    hasEffectLayer: false,
                    depth: 0
                )
            }

            for c in node.children {
                walk(c)
            }

            if node.isRasterizationRoot {
                roots.append(currentRoot!)
            }
            currentRoot = prev
        }

        walk(node)
        print("roots: \(roots.count)")

        return roots
    }
}
