import Foundation
@_spi(SwiftUI) import Observation
import Wayland

@MainActor
public class ObservationSource<T> where T: Sendable {
    fileprivate let signal: Signal<T>
    var value: T {
        signal.value
    }

    private var observationTask: Task<Void, any Error>!

    init(emit: @escaping () -> T) {
        signal = Signal(emit())
        let observations = Observations {
            emit()
        }

        observationTask = Task {
            for try await value in observations {
                self.signal.value = value
            }
        }
    }

    func destroy() {
        observationTask.cancel()
    }
}

extension Source {
    @MainActor
    static func observation<T>(emit: @Sendable @escaping () -> T) -> ObservationSource<T> {
        return ObservationSource(emit: emit)
    }
}
