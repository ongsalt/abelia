import Foundation

struct Log {
    enum Tag {
        case vulkan
        case renderLoop
        case ui
    }

    static func info(_ tag: Tag, _ message: String) {
        print("\u{001B}[32m   INFO\u{001B}[0m \(Date.now.formatFr()) [\(tag)] \(message)")
    }

    // 7
    static func warn(_ tag: Tag, _ message: String) {
        print("\u{001B}[33mWARNING\u{001B}[0m \(Date.now.formatFr()) [\(tag)] \(message)")
    }

    static func error(_ tag: Tag, _ message: String) {
        print("\u{001B}[31m  ERROR\u{001B}[0m \(Date.now.formatFr()) [\(tag)] \(message)")
    }

    static func debug(_ tag: Tag, _ message: String) {
        #if DEBUG
            print("\u{001B}[34m  DEBUG\u{001B}[0m \(Date.now.formatFr()) [\(tag)] \(message)")

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
