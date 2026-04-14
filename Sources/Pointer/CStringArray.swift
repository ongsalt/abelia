import Foundation

@resultBuilder
public struct CStringArrayBuilder {
    public static func buildBlock(_ components: String...) -> [String] {
        components
    }
}

public final class CStringArray: @unchecked Sendable {
    let strings: [String]
    // We store the pointer array itself
    private let buffer: UnsafeMutableBufferPointer<UnsafePointer<CChar>?>

    // 1. The count Vulkan needs
    public var count: UInt32 {
        UInt32(buffer.count)
    }

    public var ptr: UnsafePointer<UnsafePointer<CChar>?> {
        return UnsafePointer(buffer.baseAddress!)
    }

    public init(_ strings: [String]) {
        self.strings = strings
        // Allocate the array of pointers
        self.buffer = .allocate(capacity: strings.count)

        // Fill it with stable C-strings
        for (i, string) in strings.enumerated() {
            // strdup allocates memory on the C heap. It never moves.
            // We must free this later.
            self.buffer[i] = UnsafePointer(strdup(string))
        }
    }

    public convenience init(@CStringArrayBuilder builder build: () -> [String]) {
        self.init(build())
    }

    func leak() {
        Unmanaged.passRetained(self)
    }

    func unleak() {
        Unmanaged.passUnretained(self).takeRetainedValue()
    }

    deinit {
        // 1. Free the individual C strings
        for ptr in buffer {
            // Cast back to mutable to free
            if let ptr = ptr {
                free(UnsafeMutablePointer(mutating: ptr))
            }
        }
        // 2. Free the array of pointers
        buffer.deallocate()
    }
}

extension CStringArray: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = String

    public convenience init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}
