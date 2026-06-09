import Swinit

typealias OnEvent = @MainActor (WindowId, WindowEvent) -> Void
typealias SetupFn = @MainActor (EventLoop) -> OnEvent

@MainActor
func runEventLoop(_ block: @escaping SetupFn) {
  let r = SetupResponder(block: block)
  let eventLoop = EventLoop()!
  eventLoop.run(r)
}

private class SetupResponder: Swinit.Responder {
  typealias EventLoop = Swinit.EventLoop
  @MainActor
  let block: SetupFn

  @MainActor
  var onEvent: OnEvent?

  @MainActor
  init(block: @escaping SetupFn) {
    self.block = block
  }

  func resumed(eventLoop: EventLoop) {
    nonisolated(unsafe) let eventLoop = eventLoop
    nonisolated(unsafe) let this = self
    MainActor.assumeIsolated {
      this.onEvent = this.block(eventLoop)
    }
  }

  func windowEvent(
    eventLoop: EventLoop, windowId: SwinitCommon.WindowId, event: SwinitCommon.WindowEvent
  ) {
    // TODO: make WindowEvent sendable
    nonisolated(unsafe) let this = self
    nonisolated(unsafe) let event = event
    MainActor.assumeIsolated {
      this.onEvent?(windowId, event)
    }
  }
}
