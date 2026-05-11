// auto retracking is universal property
// but we should allow the user to set it -> its not pure then

public class Node {
    public var label: String?
    private(set) var dirty: Bool = false  // we need to do `maybeDirty`
    var dirtyCallback: (() -> Void)?
    private(set) var dependencies: Set<Node> = []
    private(set) var dependants: Set<Node> = []

    public init(label: String? = nil, onDirty dirtyCallback: (() -> Void)? = nil) {
        self.label = label
        self.dirtyCallback = dirtyCallback
    }

    public func markDirty(immediate: Bool = true) {
        dirty = true
        // idk which should run first
        if let dirtyCallback {
            // call some shi???
            dirtyCallback()
        }
        for d in dependants {
            d.markDirty(immediate: false)
        }
    }

    public func markClean() {
        dirty = false
    }

    public func addDependency(_ dep: some Sequence<Node>) {
        for d in dep {
            self.addDependency(d)
        }
    }

    public func addDependency(_ dep: Node) {
        // we should have a toggle for this
        // check if dep IS depending on current node or not

        // TODO: cycle check
        self.dependencies.insert(dep)
        dep.dependants.insert(self)
    }

    public func removeDependency(_ dep: some Sequence<Node>) {
        for d in dep {
            self.removeDependency(d)
        }
    }

    public func removeDependency(_ dep: Node) {
        self.dependencies.remove(dep)
        dep.dependants.remove(self)
    }

    public func clearDependencies() {
        for d in self.dependencies {
            d.dependants.remove(self)
        }
        self.dependencies = []
    }

    deinit {
        // print("droping \(self)")
    }
}

extension Node: CustomStringConvertible {
    public var description: String {
        "Node(label: \(label ?? "nil"))"   
    }
}

extension Node: Identifiable {}

extension Node: Equatable {
    public static func == (lhs: Node, rhs: Node) -> Bool {
        lhs.id == rhs.id
    }
}

extension Node: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
