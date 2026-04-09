func trustMeBroItIsInitialized<T>() -> T {
    withUnsafeTemporaryAllocation(of: T.self, capacity: 1) { ptr in
        ptr.baseAddress!.pointee
    }
}
