// @MainActor
protocol Source<T>: Identifiable, AnyObject {
    associatedtype T

    var subscribers: [Int: any Subscriber] {
        get
        set
    }

    var value: T {
        get
    }

    var peek: T {
        get
    }


    func addSubscriber(_ subscriber: any Subscriber)
    func removeSubscriber(_ subscriber: any Subscriber)
}

extension Source {
    func addSubscriber(_ subscriber: any Subscriber) {
        self.subscribers[subscriber.id.hashValue] = subscriber
    }

    func removeSubscriber(_ subscriber: any Subscriber) {
        subscribers.removeValue(forKey: subscriber.id.hashValue)
    }
}
