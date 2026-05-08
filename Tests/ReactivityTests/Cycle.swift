import Testing

@testable import Reactivity

@Test func cycleCrashTheProgram() async throws {
    await #expect(processExitsWith: .failure) {
        let a = Node(label: "a")
        let b = Node(label: "b")
        let c = Node(label: "c")

        b.addDependency(a)
        c.addDependency(b)
        a.addDependency(c)

        a.markDirty()
    }
}
