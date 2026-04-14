public struct Weak<T: AnyObject> {
    weak let value: T?
}

// extension Weak: Equatable where T: Equatable {
//     public static func == (lhs: Self, rhs: Self) -> Bool {
//         lhs.value == rhs.value
//     }
// }

// extension Weak: Hashable where T: Hashable {
//     public func hash(into hasher: inout Hasher) {
//         hasher.combine(value)
//     }    
// }