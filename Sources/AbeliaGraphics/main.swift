import AbeliaGraphics
import WaylandClient
import Foundation

func makeSurface(connection: Connection) throws -> (WlSurface) {
    let globals = try Globals(connection: connection)
    let compositor = try globals.bind(to: WlCompositor.self, version: 1...6)
    // let queue = connection.createEventQueue(name: "render")
    let surface = try compositor.createSurface()

    connection.roundtrip()

    return surface
}


let connection = Connection()
let wlSurface = try makeSurface(connection: connection)

let vulkanInstance = try VulkanInstance()
let surface = try vulkanInstance.createSurface(display: connection.display.raw, surface: wlSurface.raw)
let vulkanDevice = try vulkanInstance.requestDevice(compatibleWith: surface)

let watch = connection.attach()
RunLoop.main.run()
_ = watch
