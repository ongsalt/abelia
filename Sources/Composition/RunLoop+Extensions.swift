import CoreFoundation
import Foundation
import Wayland

class RunLoopObservationToken {
    let observer: RunLoopObserver

    init(_ observer: RunLoopObserver) {
        self.observer = observer
        observer.start()
    }

    deinit {
        // print("[RunLoopObservationToken] Dropped")
        observer.stop()
    }
}

extension RunLoop {
    var currentCFRunLoop: CFRunLoop {
        let _cfRunLoopStorage = Mirror(reflecting: self).children.first {
            $0.label == "_cfRunLoopStorage"
        }!.value
        let rl = unsafeBitCast(_cfRunLoopStorage, to: CFRunLoop?.self)!
        return rl
    }

    func addListener(
        on activities: [CFRunLoopActivity], repeated: Bool = true, priority: Int = 0,
        _ callback: @escaping (CFRunLoopActivity) -> Void
    ) -> RunLoopObservationToken {
        let observer = RunLoopObserver(
            on: activities,
            runLoop: currentCFRunLoop,
            repeated: repeated,
            priority: priority,
            callback
        )

        return RunLoopObservationToken(observer)
    }
}
