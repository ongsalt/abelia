import Foundation
import Synchronization

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
    var error: Failure? {
        do {
            _ = try get()
            return nil
        } catch {
            return error
        }
    }

    var value: Success? {
        do {
            return try get()
        } catch {
            return nil
        }
    }

    func unwrap() -> Success {
        expect("Fail to unwrap")
    }

    func expect(_ message: String) -> Success {
        do {
            return try self.get()
        } catch {
            print(message)
            fatalError(message)
        }
    }
}



func measure<T>(_ label: String, block: () -> T) -> T {
    var value: T!
    let duration = ContinuousClock().measure {
        value = block()
    }
    Log.debug(.general, "Finished \(label) in \(duration / .milliseconds(1))ms")
    return value!
}
