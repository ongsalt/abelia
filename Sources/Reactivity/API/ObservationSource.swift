import Foundation

import Observation

@MainActor
public class ObservationSource<T> where T: Sendable {
    @Signal
    private(set) var value: T

    private var observationTask: Task<Void, any Error>!

    init(getter: @escaping () -> T) {
        value = getter()
        let observations = Observations {
            getter()
        }

        observationTask = Task { [weak self] in
            for try await value in observations {
                guard let self else {
                    break
                }
                self.value = value
            }
        }
    }

    func destroy() {
        observationTask.cancel()
    }
}
