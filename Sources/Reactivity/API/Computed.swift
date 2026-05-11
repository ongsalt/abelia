// first we mark immediate children with .dirty
// and

// extension Computed where T: Equatable {
//     private func recompute() -> Bool {
//         node.clearDependencies()
//         var changed = false
//         let deps = TrackingContext.track {
//             let newValue = computation()
//             if newValue == storage.value {
//                 storage.value = newValue
//                 changed = true
//             }
//         }
//         node.markClean()
//         node.addDependency(deps)
//         return changed
//     }
// }
@propertyWrapper
public struct Computed<T> {
    @_spi(EmaInternal) public let node: Node = Node(label: String(describing: Computed<T>.self))

    public var value: T {
        _read {
            TrackingContext.current?.reportRead(node)

            if node.dirty.isEmpty {
                yield storage.value!
                return
            }

            // if node.dirty.contains(.dirty) {
            //     recompute()
            //     yield storage.value!
            //     return
            // }

            // if node is MAYBE dirty
            // so, for every deps that is MAYBE DIRTY
            // try calling its recompute() -> Bool
            recompute()
            yield storage.value!
        }
    }

    private var storage: Cell<T?> = Cell(nil)
    var computation: () -> T

    public init(_ computation: @escaping () -> T) {
        self.computation = computation
        node.markDirty()
    }

    private func recompute() -> Bool {
        node.clearDependencies()
        let deps = TrackingContext.track {
            storage.value = computation()
        }
        node.markClean()
        node.addDependency(deps)

        return true
    }

    // property wrapper shi
    public var wrappedValue: T {
        _read {
            yield value
        }

    }

    // this is cursed
    public init(wrappedValue: @autoclosure @escaping () -> T) {
        self.init(wrappedValue)
    }
}
extension Computed: CustomStringConvertible {
    public var description: String {
        "\(Computed<T>.self)(\(value))"
    }
}
private class Cell<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
