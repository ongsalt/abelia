import Abelia
import SwiftWayland

runEventLoop { eventLoop in
    let context = try! GraphicsContext(applicationName: "yomum", version: 12)
    let window = eventLoop.createWindow(attributes: .init(title: "hihi", size: [600, 600]))
    eventLoop.connection.roundtrip()

    window

    let surface = try! context.createWaylandSurface(display: window.display.raw, surface: window.surface.raw)
    try! context.initDevice(compatibleWith: surface)

    let renderer = try! Renderer(context: context.surfaceContexts[0])

    let root = Layer(offset: [0, 0], size: [800, 600]) {
        Layer(offset: [10, 10], size: [100, 50])
        Layer(offset: [20, 20], size: [200, 100]) {
            Layer(size: [50, 50])
        }
    }

    // print(sortLayer(root))

    try! renderer.render()

    return { id, event in
        print(event)
    }
}
