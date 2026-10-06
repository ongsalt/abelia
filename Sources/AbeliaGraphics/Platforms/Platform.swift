protocol EventLoop {
    associatedtype Window: AbeliaGraphics::Window
    func run()
    func createWindow() -> Window

    // No android support for now
    // func onReady(block: @escaping () -> Void)
}

protocol Window {
    // drawing area size
    var size: SIMD2<UInt> { get set }
}