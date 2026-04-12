// swapchain shuold be here???
class FrameClock: @unchecked Sendable {
    // var index: UInt = 0

    // private var pendingDraw: UInt? = nil
    // private var isDrawing = false

    // public var redrawEvent: AsyncStream<UInt>!
    // private var continuation: AsyncStream<UInt>.Continuation!

    // init() {
    //     redrawEvent = AsyncStream { continuation in
    //         self.continuation = continuation
    //     }
    // }

    // public var isIdle: Bool {
    //     pendingDraw == nil
    // }

    // // this shuold expose redraw trigger, a stream?
    // // TODO: fps cap, vsync, now its cpu bound: schedule as much as it can

    // func invalidate() -> UInt? {
    //     guard pendingDraw == nil else {
    //         return nil
    //     }

    //     let id = index
    //     index += 1
    //     pendingDraw = id
    //     continuation.yield(id)
    //     return id
    // }

    // func markUpdated(id: UInt) {
    //     if pendingDraw == id {
    //         pendingDraw = nil
    //     }
    // }
}

// so when we make node dirty -> it call invalidate
// then this emit redraw signal which then will wait a bit until we acquire image
// -> markUpdated
