import Foundation

// To ensure main thread is not blocked
func launchCounter() -> Task<Void, any Error> {
    Task {
        var i = 0
        while !Task.isCancelled {
            print("[count] \(i) (\(Date.now))")
            i += 1
            try await Task.sleep(for: .seconds(1))
        }
    }
}

func with<T>(_ value: T, block map: (inout T) -> Void) -> T {
    var value = value
    map(&value)
    return value
}

func run<T>(_ fn: () -> T) -> T {
    fn()
}

func drop<T>(_ value: consuming T) {}

func duplicated<T>(_ value: T) -> [4 of T] {
    [value, value, value, value]
}

func duplicated<T>(_ value: T) -> [3 of T] {
    [value, value, value]
}

func duplicated<T>(_ value: T) -> [2 of T] {
    [value, value]
}


extension Result {
    func unwrap() -> Success {
        expect("Unwrap failed")
    }

    func expect(_ message: String) -> Success {
        do {
            return try self.get()
        } catch {
            fatalError(message)
        }
    }
}