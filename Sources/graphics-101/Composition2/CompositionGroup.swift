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

enum LayerGrouping {
    case effect([EffectLayer])
    case group([_Layer])

    var isEffect: Bool {
        if case .effect(_) = self {
            return true
        }
        return false
    }

    func adding(_ layer: _Layer) -> Self {
        switch self {
        case .effect(let layers):
            guard let layer = layer as? EffectLayer else {
                fatalError("\(layer) is not effect layer")
            }
            return .effect(layers + [layer])
        case .group(let layers):
            return .group(layers + [layer])
        }
    }
}

// TODO: write a test for this
func sortLayers(_ layers: [_Layer]) -> [LayerGrouping] {
    // TODO: better algorithm
    //  -> sink every layer down until overlap with a effect layer

    var out: [LayerGrouping] = []

    for layer in layers {
        if let layer = layer as? EffectLayer {
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
                out.append(.group([layer]))
            }
        }
    }

    return out
}


func drawLayers(_ grouping: [LayerGrouping]) {
    
}