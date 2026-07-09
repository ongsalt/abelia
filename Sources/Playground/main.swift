import AbeliaGraphics
import Foundation
import Swinit

#if canImport(WaylandClient)
    import WaylandClient
#endif

EventLoop().run(Delegate())
