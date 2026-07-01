import Foundation
import Swinit
import Synchronization
import Vulkan

/// Flow
///  1. Main thread: hi there i want to render: lastRenderRequest mutex?
///  2. render thread: wait
///  3. render thread & main: pls run animation frame
///  4. render thread & main: produce pass
///  5. do its thing

@MainActor
public class Compositor {
    let frameNotifier: RenderNotifier
    private nonisolated(unsafe) let renderLoop: RenderLoop
    private nonisolated(unsafe) var renderer: Renderer

    // private var knownSurfaces: [Angle] = []
    // TODO: move compositionSurface out
    nonisolated(unsafe) private let surface: Surface
    public var root = Layer()

    private var scheduler = RenderScheduler()

    public init(surface: Surface, device: DeviceContext) throws {
        self.renderLoop = try RenderLoop(context: device, maxFrameInFlightCount: 2)
        self.renderer = try Renderer(
            context: device, frameInFlightCount: renderLoop.maxFrameInFlightCount)
        self.surface = surface
        self.frameNotifier = RenderNotifier(preRenderFrameCount: 2)

        self.startRenderThread()
    }

    public func onDirty() {
        frameNotifier.request()
    }

    public func createImage(filename: String) throws -> CompositionImage {
        let future = try renderer.textureRegistry.loadImage(filename: filename)
        return CompositionImage(future.value)
    }

    var animationFrameCallbacks: [() -> Void] = []
    public func requestAnimationFrame(callback: @escaping () -> Void) {
        animationFrameCallbacks.append(callback)
        frameNotifier.request()
    }

    func sync() -> Pass? {
        let callbacks = animationFrameCallbacks
        animationFrameCallbacks = []
        for cb in callbacks {
            cb()
        }

        // mark layers clean

        // generate pass
        let (time, pass) = measure {
            scheduler.schedule(root: root)
        }
        Log.verbose(.scheduler, "Completed batching in \((time / .milliseconds(1)))ms")
        return pass
    }

    var renderThread: Thread?
    private func startRenderThread() {
        self.renderThread = Thread { [self] in
            // block until dirty
            while frameNotifier.shouldRender() {
                do {
                    let res = try renderLoop.waitForAvailableFrameInFlight()

                    // let frameContext
                    // this should be async -> so not block main thread
                    let backBuffer = try surface.acquireCurrentTexture(
                        signalling: res.imageAvailableSemaphore)

                    let pass = DispatchQueue.main.sync { self.sync() }

                    let commands: GPUCommands = GPUCommands { [self] commandBuffer in
                        backBuffer.prepareRender().apply(to: commandBuffer)

                        if let pass {
                            // Log.info(.scheduler, pass.dumpTree())
                            do {
                                _ = try renderer.render(
                                    pass,
                                    to: backBuffer.texture.image,
                                    view: backBuffer.texture.view,
                                    in: commandBuffer
                                )
                            } catch {
                                Log.error(.compositor, "render error: \(error)")
                            }
                        } else {
                            // Log.info(.scheduler, "No pass.")
                        }

                        let c = RenderTextureState.renderTarget
                        let transitionToPresent = ImageMemoryBarrier2(
                            srcStageMask: c.stageMask, srcAccessMask: c.accessMask,
                            dstStageMask: .bottomOfPipe, dstAccessMask: .none,
                            oldLayout: c.layout, newLayout: .presentSrcKHR, srcQueueFamilyIndex: 0,
                            dstQueueFamilyIndex: 0, image: backBuffer.texture.image,
                            subresourceRange: subresourceRange

                        )
                        commandBuffer.pipelineBarrier2(
                            .init(imageMemoryBarriers: [transitionToPresent]))
                    }

                    try renderLoop.submit(
                        commands: commands,
                        waiting: res.imageAvailableSemaphore,
                        signalling: backBuffer.renderCompletedSemaphore,
                    )

                    if let ms = try renderLoop.getLatestAvailableFrameTime() {
                        Log.verbose(.compositor, "Finished frame in \(ms)ms")
                    }

                    try backBuffer.present()
                } catch {
                    Log.error(.compositor, "error: \(error)")
                }
            }
            Log.info(.compositor, "Render thread stopped")
            
            DispatchQueue.main.async {
                self.onStop?()
            }
        }

        renderThread?.start()
    }

    var onStop: (() -> Void)?
    public func stop(onStop: (() -> Void)? = nil) {
        self.frameNotifier.stop()
        self.onStop = onStop
    }
}

class RenderNotifier: @unchecked Sendable {
    let condition = NSCondition()
    let ignored: Bool
    var preRenderFrameCount: Int
    var hasRequested: Bool = false
    var shouldStop: Bool = false

    init(ignored: Bool = false, preRenderFrameCount: Int) {
        self.ignored = ignored
        self.preRenderFrameCount = preRenderFrameCount
    }

    func stop() {
        condition.withLock {
            shouldStop = true
            condition.signal()
        }
    }

    func request() {
        condition.withLock {
            hasRequested = true
            condition.signal()
        }
    }

    func shouldRender() -> Bool {
        condition.withLock {
            if shouldStop {
                return false
            }
            if ignored {
                return true
            }
            if preRenderFrameCount > 0 {
                preRenderFrameCount -= 1
                return true
            }
            if hasRequested {
                hasRequested = false
                return true
            }
            condition.wait()
            return !shouldStop
        }
    }
}
