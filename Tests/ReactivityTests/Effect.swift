import Testing

@testable import Reactivity

@Test func effect() async {
    @Signal var a = 1
    @Signal var b = 2
    @Computed var c = a + b

    await confirmation(expectedCount: 3) { confirm in
        let e = Effect {
            _ = c
            confirm()
        }

        a += 1
        // it should batch here tho
        b += 1
    }
    b += 1
}

@Test func signalEqTest() async {
    // property wrapper fuck this up
    var a = Signal(1)
    var b = Signal(2)
    @Computed var c = a.value + b.value

    await confirmation(expectedCount: 2) { confirm in
        let e = Effect {
            _ = c
            confirm()
        }

        a.value = 2
        a.value = 2
        a.value = 2
        a.value = 2
        a.value = 2
        a.value = 2
    }
}


@Test func signalInEffect() async throws {
    // so we still need to keep track of this
}
