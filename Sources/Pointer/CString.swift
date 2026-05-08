import Foundation

// TODO: make this non copyable struct
public final class CString {
    public var swiftString: String {
        didSet {
            update()
        }
    }

    private(set) var buffer: UnsafeMutablePointer<CChar>
    public var ptr: UnsafePointer<CChar> {
        UnsafePointer(buffer)
    }

    public init(_ value: String) {
        buffer = malloc(16).assumingMemoryBound(to: CChar.self)
        swiftString = value
        update()
    }

    private func update() {
        var cStr = swiftString.cString(using: .utf8)!

        buffer = realloc(buffer, cStr.count * MemoryLayout<CChar>.size)
            .assumingMemoryBound(to: CChar.self)
        strcpy_s(buffer, cStr.count, &cStr)

    }

    deinit {
        // print("free \(swiftString)")
        free(buffer)
    }
}

extension CString: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public convenience init(stringLiteral value: String) {
        self.init(value)
    }
}
