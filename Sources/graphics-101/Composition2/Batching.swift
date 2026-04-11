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
///     TODO: incremental reordering and invalidation - for now just recompute it everytime shit got invalidated

enum Batching {
    // basically copy the layer below then draw effect on top of it (by sampling layer below)
    case effect([EffectNode])
    case composite([CompositionNode])

    var isEffect: Bool {
        if case .effect(_) = self {
            return true
        }
        return false
    }

    func adding(_ layer: RenderNode) -> Self {
        switch self {
        case .effect(let layers):
            guard let layer = layer as? EffectNode else {
                fatalError("\(layer) is not effect layer")
            }
            return .effect(layers + [layer])
        case .composite(let layers):
            return .composite(layers + [layer as! CompositionNode])
        }
    }

    // n^2 lets goooo; n = layer count
    // we can skip rasterizationRoot tho
    static func compute(root: CompositionNode) -> [Batching] {
        let nodes = flatten(root)
        var out: [Batching] = []
        var topEffectBatch: [EffectNode] = []
        var topCompositionBatch: [CompositionNode] = []

        for node in nodes {
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

        return out
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

// TODO: skip rasterizationRoot
private func flatten(_ node: RenderNode) -> [RenderNode] {
    var out: [RenderNode] = []
    func walk(_ node: RenderNode) {
        if node.isRasterizationRoot && node.dirty {
            for c in node.children {
                walk(c)
            }
        }
        out.append(node)
    }
    return out
}

// TODO: better algorithm, currently its just greedy, not minimal batching group but good enough
// TODO: write a test for this
// composite node can overlap but effect is not
func sortLayers(_ layers: [RenderNode]) -> [Batching] {
    // TODO: better algorithm
    //  -> sink every layer down until overlap with a effect layer

    var out: [Batching] = []

    for layer in layers {
        if let layer = layer as? EffectNode {
            if out.last?.isEffect == true {
                // TODO: This must not overlap tho
                out.append(out.popLast()!.adding(layer))
            } else {
                out.append(.effect([layer]))
            }
        } else {
            if out.last?.isEffect == false {
                out.append(out.popLast()!.adding(layer))
            } else {
                out.append(.composite([layer as! CompositionNode]))
            }
        }
    }

    return out
}
