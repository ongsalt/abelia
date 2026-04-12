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

        let renderer = Compositor(state: vulkanState)

        setupScene(root: renderer.root)
        renderer.root.print()
        // let rect = CompositionNode()
        // rect.size = [100, 100]
        // rect.fillColor = Color(r: 1, g: 0, b: 0, a: 1)
        // renderer.root.children.append(rect)

        Task {
            await renderer.recomposite()
        }
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
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown,
    ]

    for (offset, c) in colors.enumerated() {
        let node = CompositionNode()
        node.size = [96, 96]
        node.fillColor = c
        node.position = [18 * Float(offset), 18 * Float(offset)]
        node.cornerRadius = 24

        node.shadowBlur = 12
        node.shadowColor = .black

        node.borderWidth = 0.5
        node.borderColor = .black

        root.addChild(node)
    }
}
