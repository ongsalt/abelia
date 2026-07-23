import Swinit
import AbeliaGraphics

// Assuming only 1 window for now

@MainActor
public func run(setup: @escaping () -> Void) {
    let runtime = Runtime()
    let rootNode = LayoutNode()
    rootNode.runtime = runtime

    EventLoop().run(runtime)
}

class Runtime: Swinit.EventLoopDelegate {
    var onCanCreateSurfaces: (() -> Void)?
    var mountedNodeIds: Set<Node.ID> = []

    func canCreateSurfaces(_ eventLoop: Swinit.EventLoop) {

    }

    func launchWindow() {

    }

    func windowEvent(_ eventLoop: Swinit.EventLoop, window: Swinit.Window, event: SwinitCore.WindowEvent) {
        
    }
}
