import Swinit

typealias OnEvent = @MainActor (Window, WindowEvent) throws -> Void
typealias SetupFn = @MainActor (EventLoop) throws -> OnEvent
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
    do {
      self.onEvent = try self.block(eventLoop)
    } catch {
      print(error)
      eventLoop.stop()
    }
  }

  func windowEvent(eventLoop: EventLoop, window: Window, event: WindowEvent) {
    do {
      try self.onEvent?(window, event)
    } catch {
      print(error)
    }
  }
}
