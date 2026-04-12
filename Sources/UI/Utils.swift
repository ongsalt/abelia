func garbage<T>() -> T {
    // arc retain gonna fuck this up 
    withUnsafeTemporaryAllocation(of: T.self, capacity: 1) { buffer in
        buffer[0]
    }
}
