import Foundation

struct Log {
    enum Tag {
        case vulkan
        case renderLoop
        case ui
    }

    static func info(_ tag: Tag, _ message: String) {
        print("\u{001B}[32m[i] \(Date.now.formatFr()) [\(tag)] \(message)\u{001B}[0m")
    }

    static func warn(_ tag: Tag, _ message: String) {
        print("\u{001B}[33m[w] \(Date.now.formatFr()) [\(tag)] \(message)\u{001B}[0m")
    }

    static func error(_ tag: Tag, _ message: String) {
        print("\u{001B}[31m[e] \(Date.now.formatFr()) [\(tag)] \(message)\u{001B}[0m")
    }

    static func debug(_ tag: Tag, _ message: String) {
        #if DEBUG
            print("[d] \(Date.now.formatFr()) [\(tag)] \(message)")

        #endif
    }
}

extension Date {
    fileprivate func formatFr() -> String {
        // let time = (self.timeIntervalSince1970 - floor(self.timeIntervalSince1970)).formatted(.number)
        // return "\(self.ISO8601Format(.iso8601)) \(time)"
        "\(self.timeIntervalSince1970)"
    }
}
