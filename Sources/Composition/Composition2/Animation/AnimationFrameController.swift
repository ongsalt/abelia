@MainActor
public class AnimationFrameController: Identifiable {
    let callback: (AnimationFrameController) -> Void
    unowned let compositor: Compositor

    init(_ callback: @escaping (AnimationFrameController) -> Void, _ compositor: Compositor) {
        self.callback = callback
        self.compositor = compositor
    }

    func run() {
        self.callback(self)
    }

    public func stop() {
        compositor.animationFrameControllers[id] = nil
    }
}
