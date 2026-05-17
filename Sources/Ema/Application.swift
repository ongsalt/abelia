import EmaCore
import Swinit

class Responder: Swinit.Responder, @unchecked Sendable {
  typealias EventLoop = Swinit.EventLoop
  
  var runtime: Runtime

  init(_ runtime: Runtime) {
    self.runtime = runtime
  }

  func resumed(eventLoop: EventLoop) {
    // eventloop should also be sendable
    // it should be more like
    //  we have runtimes(without window) -> create it
    nonisolated(unsafe) let eventLoop = eventLoop
    
    MainActor.assumeIsolated {
      runtime.eventLoop = eventLoop
      #if os(Linux)
        let window = eventLoop.createWindow(attributes: .init(title: "nah"))
      #endif

      #if os(Windows)
        let window = eventLoop.createWindow(
          attributes: .init(title: "nah", noRedirectionBitmap: true))
        window.drawUnderTitleBar = true
        window.backdropStyle = .acrylic
      // TODO: support darkmode
      #endif

      let context = GraphicsContext(appName: "Playground")
      let surface = context.createSurface(for: window)
      let device = context.createDevice(compatibleWith: surface)
      surface.configure(associateWith: device)

      let compositor = Compositor(surface: surface, device: device)

      runtime.initializeRendering(compositor, window)

      compositor.animationFrameCallback = { [weak runtime] in
        runtime?.flushOnFrame()
      }
    }
  }

  func windowEvent(
    eventLoop: EventLoop, windowId: Swinit.WindowId, event: Swinit.WindowEvent
  ) {
    // event shuold be sendable tbh
    nonisolated(unsafe) let event = event
    MainActor.assumeIsolated {
      self.runtime.sendWindowEvent(event)
    }
  }

  func createWindow() {

  }
}

/// This assume single window app
/// TODO: think about multi windows
///   swiftui way seem weird
@MainActor
public func runApp(@ViewBuilder _ body: @escaping () -> Body) {
  let eventLoop = EventLoop()!

  let responder = Responder(Runtime(contents: body))

  eventLoop.run(responder)
}

