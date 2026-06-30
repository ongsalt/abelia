struct RenderScheduler {
    var transformResolver = TransformResolver()
    var compositionPlanner = CompositionPlanner()
    var passScheduler = PassScheduler()

    mutating func schedule(root: _BaseLayer) -> Pass? {
        transformResolver.resolve(root: root)
        let group = compositionPlanner.plan(root: root)
        let pass = passScheduler.schedule(root: group, transformResolver)

        return pass
    }
}

struct TransformResolver {
    typealias LayerID = _BaseLayer.ID
    var affineCache: [LayerID: Affine] = [:]

    func get(_ layer: borrowing _BaseLayer) -> Affine? {
        affineCache[layer.id]
    }

    mutating func resolve(root: _BaseLayer) {
        func walk(_ layer: _BaseLayer, _ affine: Affine?) {
            affineCache[layer.id] =
                affine?.multiplied(by: layer.localTotalAffine) ?? layer.localTotalAffine

            if layer.isRasterizationRoot {
                for l in layer.children {
                    walk(l, nil)
                }
            } else {
                for l in layer.children {
                    // accumulate it
                    walk(l, affine)
                }
            }
        }

        walk(root, nil)

    }
}

// for group opacity/clip (like LayerVisual)
// should compute content offset: in case that this is larger than parent
struct CompositionPlanner {
    func plan(root: _BaseLayer) -> CompositionGroup {
        var current = CompositionGroup(root: root, isRoot: true)

        func walk(_ layer: _BaseLayer, in group: inout CompositionGroup) {
            group.layers.append(layer)

            if layer.isRasterizationRoot {
                var new = CompositionGroup(root: layer, layers: [])
                for l in layer.children {
                    walk(l, in: &new)
                }

                group.dependencies[layer.id] = new
            } else {
                for l in layer.children {
                    walk(l, in: &group)
                }
            }
        }

        for c in root.children {
            walk(c, in: &current)
        }

        return current
    }
}

struct CompositionGroup {
    var root: _BaseLayer
    var layers: [_BaseLayer] = []

    typealias LayerID = _BaseLayer.ID
    var dependencies: [LayerID: CompositionGroup] = [:]

    // TODO: handle skipping composition group, might just emit 1 RenderNode
    var skippable: Bool = false
    var isRoot: Bool = false
}

struct PassScheduler {
    func schedule(
        root: borrowing CompositionGroup,
        _ transformResolver: borrowing TransformResolver
    ) -> Pass? {
        func makeNewPass(basedOn layer: _BaseLayer, affine: Affine, key: Int) -> Pass {
            switch layer.kind {
            case .composite:
                let node = (layer as! Layer).compositeRenderNode(affine)
                let new = Pass(target: .sameAsPrevious(key: key))
                new.addRenderNode(node)
                return new

            case .blur:
                let region = (layer as! EffectLayer).blurRegion(affine)
                let new = Pass(target: .sameAsPrevious(key: key))
                new.kind = .blur(regions: [region])
                return new

            case .effect:
                let region = (layer as! EffectLayer).effectRegion(affine)
                let new = Pass(target: .alternate(key: key))
                new.kind = .effect(regions: [region])
                return new
            }
        }

        func walk(_ group: borrowing CompositionGroup) -> Pass? {  // return last past
            let key = group.root.id

            // initially composite, might not reuse texture, also need to calculate it size with child
            let layer = group.root
            let affine = transformResolver.get(layer)!
            let bounds = layer.bounds.transformBounds(affine)
            if bounds.size == .zero {
                return nil
            }

            // TODO: implicit group texture size
            let pass = Pass(
                target: .new(size: SIMD2(bounds.size), key: key, canTransfer: group.isRoot))

            // inlinable contents from root layer
            // shadow will be render by parent instead
            if let r = root.root as? Layer,
                let node = r.compositionGroupRootRenderNode()
            {
                pass.addRenderNode(node)
            }

            // all use the same texture size
            var localPasses = [pass]
            outer: for layer in group.layers {
                let affine = transformResolver.get(layer)!
                let bounds = layer.bounds.transformBounds(affine)

                // add it to topmost non covered matching pass
                // otherwise create a pass
                for p in localPasses.lazy.reversed() {
                    switch p.kind {
                    case .composite:
                        if layer.kind == .composite {
                            if layer.isRasterizationRoot {
                                // add sampling mode
                                p.addRenderNode(
                                    (layer as! Layer).renderNode(sampling: key, affine))
                                if let new = walk(group.dependencies[layer.id]!) {
                                    p.dependencies.append(new)
                                }
                            } else {
                                p.addRenderNode((layer as! Layer).compositeRenderNode(affine))
                            }
                            continue outer
                        } else if p.overlap(with: bounds) {  // other kind of node that overlap
                            // force new pass
                            let new = makeNewPass(basedOn: layer, affine: affine, key: key)
                            new.dependencies.append(localPasses.last!)
                            localPasses.append(new)
                            continue outer
                        }  // other kind of node that DO NOT overlap. just continue searching

                    // if overlap -> force new pass
                    case .blur:
                        if p.overlap(with: bounds) {
                            // force new pass, based on that node kind
                            let new = makeNewPass(basedOn: layer, affine: affine, key: key)
                            new.dependencies.append(localPasses.last!)
                            localPasses.append(new)
                            continue outer
                        } else if layer.kind == .blur {
                            p.addBlurRegion((layer as! EffectLayer).blurRegion(affine))
                            continue outer
                        }

                    case .effect:
                        if p.overlap(with: bounds) {
                            let new = makeNewPass(basedOn: layer, affine: affine, key: key)
                            new.dependencies.append(localPasses.last!)
                            localPasses.append(new)
                            continue outer
                        } else if layer.kind == .effect {
                            p.addEffectRegion((layer as! EffectLayer).effectRegion(affine))
                            continue outer
                        }
                    }

                }

                // not found
                let new = makeNewPass(basedOn: layer, affine: affine, key: key)
                new.dependencies.append(localPasses.last!)
                localPasses.append(new)
            }

            return localPasses.last!
        }

        return walk(root)
    }
}

class Pass {
    // indices of other pass
    var kind: PassKind
    var dependencies: [Pass] = []
    // some time this do not change
    var target: PassRenderTarget

    init(target: PassRenderTarget) {
        kind = .composite(nodes: [])
        self.target = target
    }
}

extension Pass {
    func overlap(with rect: Rect) -> Bool {
        switch kind {
        case .composite(_, _):
            return false

        case .blur(let regions):
            for r in regions {
                let bounds = r.shape.bounds.atOrigin.transformBounds(r.affine)
                // print("comparing \(bounds) with \(rect)")
                if bounds.overlap(with: rect) {
                    return true
                }
            }
            return false

        case .effect(let regions):
            for r in regions {
                let bounds = r.shape.bounds.atOrigin.transformBounds(r.affine)
                if bounds.overlap(with: rect) {
                    return true
                }
            }
            return false

        }
    }

    func addRenderNode(_ node: RenderNode) {
        guard case .composite(var nodes, let useCustomBlend) = kind else {
            fatalError("Invalid state")
        }
        nodes.append(node)
        self.kind = .composite(nodes: nodes, useCustomBlend: useCustomBlend)
    }

    func addBlurRegion(_ region: BlurRegion) {
        guard case .blur(var regions) = kind else {
            fatalError("Invalid state")
        }
        regions.append(region)
        self.kind = .blur(regions: regions)
    }

    func addEffectRegion(_ region: EffectRegion) {
        guard case .effect(var regions) = kind else {
            fatalError("Invalid state")
        }
        regions.append(region)
        self.kind = .effect(regions: regions)
    }

    public func dumpTree(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var info = "\(type(of: self)) "

        let k =
            switch kind {
            case .blur(let regions): "blur (\(regions.count))"
            case .composite(let nodes, _): "composite (\(nodes.count))"
            case .effect(let regions): "effect (\(regions.count))"
            }

        info += "kind=\(k) target=\(target)"
        var result = "\(prefix)- \(info)\n"

        for child in self.dependencies {
            result += child.dumpTree(indent: indent + 1)
        }
        return result
    }
}

enum PassKind {
    case composite(nodes: [RenderNode], useCustomBlend: Bool = false)
    case blur(regions: [BlurRegion])
    case effect(regions: [EffectRegion])
}

enum LayerKind {
    case composite
    case blur
    case effect
}

extension _BaseLayer {
    fileprivate var kind: LayerKind {
        if self is Layer {
            return .composite
        } else if let s = self as? EffectLayer {
            if case .blur(_) = s.effect {
                return .blur
            } else {
                return .effect
            }
        }
        fatalError("impossible")
    }
}

enum PassRenderTarget {
    // per CompositionGruop, cache
    case new(size: SIMD2<UInt32>, key: Int, canTransfer: Bool = false)
    // for one pass effect
    case alternate(key: Int)
    case sameAsPrevious(key: Int)

    var key: Int {
        switch self {
        case .new(_, let key, _): key
        case .alternate(let key): key
        case .sameAsPrevious(let key): key
        }
    }
}

// write shit to gpu storage

extension Layer {
    func compositeRenderNode(_ affine: Affine) -> RenderNode {
        var node = RenderNode()
        node.brush = brush?.brush ?? .solid(.transparent)
        node.shape = shape
        if let border {
            node.border = NodeBorder(width: border.width, brush: border.brush.brush)
        }
        if let shadow {
            node.shadow = NodeShadow(
                offset: shadow.offset, blur: shadow.blur, spread: shadow.spread,
                color: shadow.color, opacity: shadow.opacity)
        }
        node.affine = affine
        return node
    }

    func compositionShapeRenderNodes(_ affine: Affine) -> [RenderNode] {
        []
    }

    // mark - CompositionGroup root
    // for inlining self content into the texture
    func compositionGroupRootRenderNode() -> RenderNode? {
        if let brush = brush?.brush {
            var node = RenderNode()
            node.brush = brush
            node.shape = shape
            // no shadow/border
            // actually border can be in both this texture and parent
            let translated = shape.bounds.topLeft
            node.affine = Affine.identity.translated(x: -translated.x, y: -translated.y)
            return node
        }

        return nil
    }

    // textureIndex will be key before we resolve that to actual texture id
    // it will need to be resove again in writing pass
    //
    // this need to render content that can not be included in the subgroup such as shadow
    func renderNode(sampling key: Int, _ affine: Affine) -> RenderNode {
        var node = RenderNode()
        node.brush = .backdrop(key: key)
        node.shape = Shape.rect(
            width: size.x, height: size.y, cornerRadius: cornerRadius, cornerDegree: cornerDegree)
        if let border {
            node.border = NodeBorder(width: border.width, brush: border.brush.brush)
        }
        if let shadow {
            node.shadow = NodeShadow(
                offset: shadow.offset, blur: shadow.blur, spread: shadow.spread,
                color: shadow.color, opacity: shadow.opacity)
        }
        node.affine = affine
        return node
    }
}

extension EffectLayer {
    // it actually another shader
    func effectNode(sampling textureIndex: UInt32, affine: Affine) -> EffectNode {
        EffectNode(
            samplingTextureIndex: textureIndex,
            region: EffectRegion(
                shape: shape,
                affine: affine,
                effect: effect
            )
        )
    }

    func blurNode(sampling textureIndex: UInt32, affine: Affine) -> BlurNode {
        guard case .blur(let radius) = self.effect else {
            fatalError("Not a blur node")
        }
        return BlurNode(
            samplingTextureIndex: textureIndex,
            region: BlurRegion(
                shape: shape,
                affine: affine,
                radius: radius
            )
        )
    }

    func blurRegion(_ affine: Affine) -> BlurRegion {
        guard case .blur(let radius) = self.effect else {
            fatalError("Not a blur node")
        }
        return BlurRegion(
            shape: shape,
            affine: affine,
            radius: radius
        )
    }

    func effectRegion(_ affine: Affine) -> EffectRegion {
        return EffectRegion(
            shape: shape,
            affine: affine,
            effect: effect
        )
    }

}
