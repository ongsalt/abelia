extension String {
    public init<T>(cStringPointer ptr: inout T) {
        self = withUnsafePointer(to: &ptr) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 256) { pointer in
                String(cString: pointer)
            }
        }
    }
}
