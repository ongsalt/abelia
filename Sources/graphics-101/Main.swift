@preconcurrency import CVMA
import CoreFoundation
import Foundation
import Synchronization
import Wayland

@MainActor
func Counter() -> some UIElement {
    let count: Signal<Float> = Signal(0.0)

    // Compositor.current?.requestAnimationFrame { time in
    //     count.value = Float(time.attoseconds / 1_000_000_000_000_000)
    //     // print(count.value)
    //     if count.value > 4800 {
    //         return .done
    //     }
    //     return .ongoing
    // }

    return VStack(gap: 12) {
        UIBox()
            .background(.red)
            .size([100, 100])
            .offset([count.value / 4, 0])
        UIBox()
            .background(.green)
            .size([100, 100])
        UIBox()
            .background(.blue)
            .size([100, 100])
            .cornerRadius(36)
        UIBox()
            .background(.white)
            .size([100, 100])
            .cornerRadius(36)
            .border(width: 1, color: .neutral200)
            .shadow(color: .black.multiply(opacity: 0.22), blur: 28)

    }
}

@MainActor
func Window() -> some UIElement {
    ZStack {
        ZStack {
            Counter()
        }
        .size([500, 500])
        .background(.white)
        .cornerRadius(48)
        .border(width: 1, color: .neutral200)
        .shadow(color: .black.multiply(opacity: 0.22), blur: 28)
    }
    .alignment(horizontal: .center, vertical: .center)
}

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

        let vulkanState = VulkanState(
            waylandDisplay: display.display,
            waylandSurface: window.surface.surface
        )

        let renderer = try UIRenderer(
            state: vulkanState, onFinishCallback: { display.dispatchPending() })

        let compositor = Compositor(
            renderer: renderer,
            size: [
                Float(vulkanState.swapChain.extent.width),
                Float(vulkanState.swapChain.extent.height),
            ]
        )

        Compositor.current = compositor

        // let l = Layer(rect: Rect.init(center: [100, 100], size: [100, 100]))
        // l.backgroundColor = .red
        // compositor.rootLayer.addChild(l)

        // Task {
        //     try await Task.sleep(for: .seconds(3))
        //     let l = Layer(rect: Rect.init(center: [200, 200], size: [100, 100]))
        //     l.backgroundColor = .blue
        //     compositor.rootLayer.addChild(l)
        // }

        let runtime = UIRuntime(
            layer: compositor.rootLayer,
            element: Window()
        )
        runtime.start()

        Task {
            try await Task.sleep(for: .seconds(1))
            compositor.printLayer()
        }

        RunLoop.main.run()
        drop(token)
    }
}
