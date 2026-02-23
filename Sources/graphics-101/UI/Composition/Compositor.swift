import Wayland

// TODO: fast damage rect lookup
@MainActor
class Compositor {
    nonisolated(unsafe) static var current: Compositor?

    private let renderer: UIRenderer
    let rootLayer: Layer
    var damagedLayers: [Layer: [Invalidation]] = [:]
    var isFirstFrame: Bool = true

    /// aka needed render loop
    var shouldRedraw: Bool {
        isFirstFrame || animationFrameRequests.count != 0 || damagedLayers.count != 0
    }

    private var renderTask: Task<Void, any Error>? = nil
    private var animationFrameRequests: [AnimationFrameRequest] = []

    init(renderer: UIRenderer, size: SIMD2<Float>) {
        self.renderer = renderer
        rootLayer = Layer(rect: Rect(top: 0, left: 0, width: size.x, height: size.y))
        rootLayer.compositor = self

        scheduleRedraw()
    }

    func invalidateLayer(layer: Layer, invalidation: Invalidation) {
        // tell someone we need rerender, kinda requestAnimationFrame
        // print("who tf call this \(layer.bounds) \(invalidation)")
        self.damagedLayers[layer, default: []].append(invalidation)

        scheduleRedraw()
    }

    func requestAnimationFrame(_ block: @escaping AnimationCallback) {
        animationFrameRequests.append(AnimationFrameRequest(callback: block, createdAt: .now))

        // scheduleRedraw()
    }

    private func runAnimation() {
        var toRemove: [Int] = []
        for (index, a) in animationFrameRequests.enumerated() {
            if a.run() == .done {
                toRemove.append(index)
            }
        }

        for i in toRemove.reversed() {
            animationFrameRequests.remove(at: i)
        }
    }

    private func flushDrawCommand() -> DrawInfo {
        defer {
            damagedLayers = [:]
        }

        // this is just redraw everything
        var commands: [DrawCommand] = []

        func traverse(layer: Layer, transformation: AffineMatrix) {
            let combined = transformation * layer.totalTransformation
            commands.append(contentsOf: layer.getLayerDrawCommands(transformation: combined))

            for c in layer.children {
                traverse(layer: c, transformation: combined)
            }
        }

        traverse(layer: rootLayer, transformation: .identity)
        // print(commands)

        let d = DrawInfo(
            damagedArea: [rootLayer.bounds], commands: groupDrawCommand(commands: commands))

        return d

        // var commands: [DrawCommand] = []
        // // damagedLayers

        // let info = DrawInfo(damagedArea: [], commands: groupDrawCommand(commands: commands))

        // return info
    }

    private func scheduleRedraw() {
        if renderTask != nil {
            return
        }
        renderTask = Task {
            while !Task.isCancelled && shouldRedraw {
                isFirstFrame = false
                await renderer.render {
                    self.runAnimation()
                    return self.flushDrawCommand()
                }
            }
            // print("bruh")
            renderTask = nil
        }
    }

    func printLayer(_ layer: Layer? = nil, level: Int = 0) {
        let layer = layer ?? self.rootLayer
        print("\(String(repeating: " ", count: level))[\(layer.id)] \(layer.frame)")

        for c in layer.children {
            printLayer(c, level: level + 1)
        }
    }
}

/// Alternative: CALayer style
/// - we gonna have a layer tree which will or will not contain backing texture
/// - transformation
/// - or just make 1 layer a fucking rounded rect
/// - clipping
///     - clip sublayer to parent (easy: no texture need, just more vertex data)
///     - clip to other layer (alpha map??)
/// - sublayer...
/// - backdrop filter
/// - Compositing/color blend mode
/// - damage reporting
/// - this do make some behavior easier:
///     - hitbox can easily be independent of layout animation
///     - alternative: lookahead scope?
///     - how does flutter do this
/// - Compositor then
///     - batch change (Layer, [Change])
///     - for now, just use the most retard way: redraw everything
///     - at least 3 layer
///     - below, above, animating
///
///
