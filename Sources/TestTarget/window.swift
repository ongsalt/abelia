import Swinit

typealias OnEvent = @MainActor (Window, WindowEvent) -> Void
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
    self.onEvent = self.block(eventLoop)
  }

  func windowEvent(eventLoop: EventLoop, window: Window, event: WindowEvent) {
    self.onEvent?(window, event)
  }
}
