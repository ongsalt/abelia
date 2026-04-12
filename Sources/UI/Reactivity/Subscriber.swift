@MainActor
protocol Subscriber: Identifiable, AnyObject {
    var dependencies: [Int: any Source] {
        get
        set
    }

    func update()

    func addDependency(_ dep: any Source)
    func removeDependency(_ dep: any Source)
}

extension Subscriber {
    func addDependency(_ dep: any Source) {
        self.dependencies[dep.id.hashValue] = dep
    }

    func removeDependency(_ dep: any Source) {
        self.dependencies.removeValue(forKey: dep.id.hashValue)
    }
}
