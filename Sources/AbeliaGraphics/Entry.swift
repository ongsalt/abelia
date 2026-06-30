// import Swinit

@MainActor
public func buildLayers() -> Layer {
    // EventLoop().run(Delegate())
    let layer = Layer(
        size: [100, 100], brush: .solid(.red),
    )
    layer.insert {
        Layer(
            offset: [0, 0, 0],
            size: [50, 50],
            brush: .solid(.blue),
            cornerRadius: 12,
            border: Border(),
            // shadow: Shadow(),
        )

        Layer(
            offset: [50, 0, 0],
            size: [50, 50],
            brush: .solid(.cyan),
            cornerRadius: 12,
            border: Border(),
            // shadow: Shadow(),
        )

        Layer(
            offset: [0, 50, 0],
            size: [50, 50],
            brush: .solid(.teal),
            cornerRadius: 12,
            border: Border(),
            // shadow: Shadow(),
        )

        Layer(
            offset: [50, 50, 0],
            size: [50, 50],
            brush: .solid(.green),
            cornerRadius: 12,
            border: Border(),
            // shadow: Shadow(),
        )
    }
    // let layer = nonOverlapBlurGrid(w: 2, h: 2)
    // layer.label = "RootFr"
    // layer.insert(Layer(offset: [5, 5, 0], size: [10, 10]))
    // // transparent subtree
    // let subtree = Layer(offset: [5, 5, 0], size: [10, 10], opacity: 0.5, brush: .solid(.red)) {
    //     Layer(offset: [1, 1, 1], size: [10, 10], brush: .solid(.green))
    //     Layer(offset: [2, 2, 2], size: [100, 100], brush: .solid(.blue))
    // }
    // subtree.label = "subtree"
    // layer.insert(subtree)

    // layer.insert {
    //     EffectLayer(
    //         offset: [12, 12, 0],
    //         shape: Shape.rect(width: 3, height: 3),
    //         effect: .refraction(amount: 10, height: 10)
    //     )
    // }

    return layer

}

extension Pass {
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

func nonOverlapBlurGrid(w: Int, h: Int, size: Float = 10) -> Layer {
    let root = Layer(size: SIMD2(Float(w) * size, Float(h) * size))
    print(root.bounds)
    for x in 0..<w {
        for y in 0..<h {
            root.insert(
                EffectLayer(
                    offset: SIMD3(Float(x) * size, Float(y) * size, 0),
                    shape: Shape.rect(width: size, height: size, cornerRadius: 10),
                    effect: .blur(radius: 20)
                )
            )
        }
    }

    return root
}
