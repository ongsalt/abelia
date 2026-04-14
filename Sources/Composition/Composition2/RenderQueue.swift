class RenderQueue {
    private var pendingFrame = 0
    let (recv, send) = AsyncStream<Void>.makeStream()

    func schedule() {
        if pendingFrame != 0 {
            return
        }
        pendingFrame += 1
        send.yield()
    }

    func onFrame(fn: @Sendable () async -> Void) async {
        for await _ in recv {
            print("Emit")
            await fn()
            print("Done")
            pendingFrame -= 1
        }
    }
}
