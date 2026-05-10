import EmaCore
import Swinit

extension GraphicsContext {
  public func createSurface(for window: Window) -> Surface {
    #if os(Windows)
      Surface(self, hinstance: window.hInstance, hwnd: window.handle)
    #endif
  }
}
