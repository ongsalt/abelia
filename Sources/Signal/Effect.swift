import Foundation
import Observation

// this wont work if there is nested effect?
@MainActor
public class Effect: EffectOwner {
    private let fn: () -> Void
    private let owner: EffectOwner? = Graph.currentEffectOwner

    public init(_ fn: @escaping () -> Void) {
        self.fn = fn
        owner?.add(self)

        update()
    }

    private func update() {
        dispose()
        withObservationTracking {
            Graph.run(with: self) {
                fn()
            }
        } onChange: {
            // this shi will be run in any order
            Task { @MainActor [weak self] in
                self?.update()
            }
        }
    }

    deinit {
        print("refcountedddd")
    }

    // static func onDeinit(_ fn: () -> Void) {

    // }

    private var children: [Effect] = []
    func add(_ effect: Effect) {
        children.append(effect)
    }

    func dispose() {
        children = []
    }
}
