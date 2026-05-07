import Testing

@testable import Reactivity

@Test func effect() async {
    @Signal var a = 1
    @Signal var b = 2
    @Computed var c = a + b

    await confirmation(expectedCount: 3) { confirm in
        let e = Effect {
            _ = c
            print(c)
            confirm()
        }

        a += 1
        // it should batch here tho
        b += 1
    }
    b += 1
}
