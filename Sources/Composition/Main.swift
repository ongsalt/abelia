@preconcurrency import CVMA
import CoreFoundation
import Foundation
import Synchronization
import Wayland

@main
@MainActor
struct Graphics101 {
    static func main() throws {
        let instance = Graphics101()
        try instance.run()
    }

    func run() throws {
        let display = try Display()
        display.monitorEvents()

        let window: RawWindow = RawWindow(display: display, title: "yomama")
        window.show()

        let token = RunLoop.main.addListener(on: [.beforeWaiting]) { _ in
            // print("Will sleep")
            display.dispatchPending()
            display.flush()
        }

        // TODO: mova wl stuff out
        let vulkanState = VulkanState(
            waylandDisplay: display.display,
            waylandSurface: window.surface.surface
        )

        let compositor = Compositor(state: vulkanState)

        Task {
            func drawText(text: String) async -> RenderTexture {
                let (ink, logical) = compositor.textRenderer.measure(text: text)
                // TODO: transfer this to gpu
                let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(
                    capacity: Int(logical.height * logical.width))
                buffer.initialize(repeating: 0)
                _ = compositor.textRenderer.render(
                    text, to: buffer, width: logical.width, height: logical.height)

                let texture = await compositor.textureRegistry.createStaticTexture(
                    from: buffer,
                    size: [UInt32(logical.width), UInt32(logical.height)],
                    format: VK_FORMAT_R8_UNORM
                )

                return texture
            }

            // Complex Profile Card UI
            let card = CompositionNode()
            card.size = [240, 240]
            card.fillColor = .white
            card.position = [220, 60]  // Centered-ish in the window
            card.cornerRadius = 32
            card.shadowBlur = 28
            card.shadowOffset = [0, 16]
            card.shadowColor = .black.multiply(opacity: 0.15)
            compositor.root.addChild(card)

            // Name
            let nameTex = await drawText(text: "Jane Swift")
            let nameNode = CompositionNode()
            nameNode.contents = nameTex
            nameNode.size = SIMD2(nameTex.size)
            nameNode.position = [(240 - Float(nameTex.size.x)) / 2, 100]  // Centered text
            nameNode.tintColor = .black
            card.addChild(nameNode)

            setupScene(root: compositor.root)

            compositor.root.print()
            // await compositor.recomposite()
            // compositor.scheduleRecomposite()
        }

        // Task {
        //     try await Task.sleep(for: .seconds(1))
        //     let node = CompositionNode()
        //     node.shouldRasterize = true
        //     node.size = [96, 96]
        //     node.fillColor = .red
        //     node.position = [0, 200]
        //     node.cornerRadius = 24
        //     node.opacity = 0
        //     compositor.root.addChild(node)

        //     let clock = ContinuousClock()
        //     let start = clock.now

        //     compositor.requestAnimationFrame { controller in
        //         var progress = (clock.now - start) / .milliseconds(400)
        //         if progress >= 1 {
        //             progress = 1
        //             controller.stop()
        //         }
        //         let animProgress = Float(1 - pow(1 - progress, 3))
        //         node.opacity = animProgress
        //         node.position.x = animProgress * 100

        //     }
        // }

        // Task {
        //     let renderer = await Renderer2(state: vulkanState)
        //     await renderer.perform()

        //     _ = Unmanaged.passRetained(renderer)  // for now
        // }

        RunLoop.main.run()
        drop(token)
    }
}

func setupScene(root: CompositionNode) {
    let colors: [Color] = [
        .red, .orange,
        // .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown,
    ]

    for (offset, c) in colors.enumerated() {
        let node = CompositionNode()
        node.shouldRasterize = true
        node.size = [96, 96]
        node.fillColor = c
        node.position = [24 * Float(offset), 24 * Float(offset)]
        node.cornerRadius = 24

        node.shadowBlur = 18
        node.shadowColor = .black.multiply(opacity: 0.4)

        // node.borderWidth = 0.5
        // node.borderColor = .black

        root.addChild(node)
    }
}
