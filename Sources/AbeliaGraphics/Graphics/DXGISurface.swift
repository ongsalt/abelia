#if os(Windows)

import Foundation
import CPlatform
import WinSDK
import Vulkan

class DXGISurface: Surface2 {
    typealias SurfaceImage = DXGISurfaceImage

    var device: DeviceContext!
    let releaseQueue: ReleaseQueue = ReleaseQueue()

    var info: ConfiguredInfo?
    struct ConfiguredInfo {
        var config: SurfaceConfiguration2
        var availableWidth: UInt32
        var availableHeight: UInt32

        var importedImageHandles: [HANDLE]
        var images: [Image]
        var imageViews: [ImageView]

        var importedSemaphore: Semaphore
    }

    var frameLatency: Int {
        get {
            2
        }
        set {
            fatalError("unimplemented")
        }
    }


    func acquire() throws(SurfaceAcquireError) -> SurfaceImage {
        fatalError()
    }


    func wait() {
        
    }

    func configure(_ configuration: SurfaceConfiguration2) {
        
    }
}

struct DXGISurfaceImage: SurfaceImageProtocol {
    var image: Image
    var view: ImageView

    /// viewport size (might be smaller than actual size)
    var width: UInt32
    var height: UInt32

    /// DXGI: nil -> will do timeline semaphore
    var acquireWait: Semaphore? { nil }
    var renderFinishedSignal: Semaphore? { nil }
    var inFlightFence: Fence? { nil }
    var finalLayout: ImageLayout { .transferSrcOptimal }

    func present() throws {

    }
}

#endif
