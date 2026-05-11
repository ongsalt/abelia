import Testing
@testable @_spi(EmaInternal) import Reactivity

@Test func computedSmth() {
    let a = Signal(1)
    let b = Signal(2)

    let c = Computed {
        a.value + b.value
    }

    #expect(c.value == 3)
    a.value += 1
    #expect(c.value == 4)
}

@Test func computedButPropertyWrapper() {
    @Signal var a = 1
    @Signal var b = 2

    @Computed var c = a + b

    #expect(c == 3)
    a += 1
    #expect(c == 4)
}

@Test func computedRetracking() {
    @Signal var a = 1
    @Signal var b = 1
    @Signal var c = 1

    @Computed var d =
        if a % 2 == 0 {
            b * 2
        } else {
            c * 5
        }

    #expect(d == 5)
    #expect(_d.node.dependencies.count == 2)
    a += 1
    #expect(d == 2)
    #expect(_d.node.dependencies.count == 2)
    a += 1
    b += 1
    c += 1
    #expect(d == 10)
    #expect(_d.node.dependencies.count == 2)
    a += 1
    #expect(d == 4)
}

@Test func computedALot() {
    @Signal var a = 1
    @Signal var b = 1

    @Computed var c = a * 2
    @Computed var d = b * 3
    @Computed var e = c + 8 - d

    #expect(e == 7)
    b += 1
    #expect(e == 4)
    // print(_e.node.dependencies)
    a += 5
    #expect(e == 14)
}
