import Foundation

struct Log {
    enum Tag {
        case general
        case renderer
        case compositor
        case gpuStorage
        case scheduler
        case textureRegistry
        case vulkan

        var colored: String {
            switch self {
            case .general: return "\u{001B}[37m\(self)\u{001B}[0m"
            case .renderer: return "\u{001B}[35m\(self)\u{001B}[0m"
            case .compositor: return "\u{001B}[36m\(self)\u{001B}[0m"
            case .gpuStorage: return "\u{001B}[33m\(self)\u{001B}[0m"
            case .scheduler: return "\u{001B}[34m\(self)\u{001B}[0m"
            case .textureRegistry: return "\u{001B}[32m\(self)\u{001B}[0m"
            case .vulkan: return "\u{001B}[31m\(self)\u{001B}[0m"
            }
        }
    }

    nonisolated(unsafe) static var displayedTags: Set<Tag> = [
        .general,
        .renderer,
        .compositor,
        .gpuStorage,
        .scheduler,
        .textureRegistry,
        .vulkan,
    ]

    static func info(_ tag: Tag, _ message: String, align: Bool = true) {
        log("\u{001B}[32m   INFO\u{001B}[0m", tag, message, align: align)
    }

    static func warn(_ tag: Tag, _ message: String, align: Bool = true) {
        log("\u{001B}[33mWARNING\u{001B}[0m", tag, message, align: align)
    }

    static func error(_ tag: Tag, _ message: String, align: Bool = true) {
        log("\u{001B}[31m  ERROR\u{001B}[0m", tag, message, align: align)
    }

    static func debug(_ tag: Tag, _ message: String, align: Bool = true) {
        #if DEBUG
            // log("\u{001B}[34m  DEBUG\u{001B}[0m", tag, message, align: align)
        #endif
    }

    private static func log(_ levelColored: String, _ tag: Tag, _ message: String, align: Bool) {
        if !displayedTags.contains(tag) {
            return
        }
        let timestamp = Date.now.formatFr()
        guard align, message.contains("\n") else {
            print("\(levelColored) \(timestamp) \(tag.colored) \(message)")
            return
        }
        // 7 (level) + 1 + timestamp + 1 + tag name + 1
        let indent = String(repeating: " ", count: 7 + 1 + timestamp.count + 1 + "\(tag)".count + 1)
        let aligned = message.components(separatedBy: "\n")
            .enumerated()
            .map { $0.offset == 0 ? $0.element : indent + $0.element }
            .joined(separator: "\n")
        print("\(levelColored) \(timestamp) \(tag.colored) \(aligned)")
    }
}

private let _logDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()

extension Date {
    fileprivate func formatFr() -> String {
        let base = _logDateFormatter.string(from: self)
        let micros = Int(self.timeIntervalSince1970 * 1_000_000) % 1_000_000
        return "\(base).\(String(format: "%06d", abs(micros)))"
    }
}
