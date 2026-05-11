import Testing
@testable import Ema
import Reactivity

struct ExpectedNode {
    let name: String
    let pos: (Float, Float)
    let size: (Float, Float)
    var children: [ExpectedNode] = []

    func dump(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var result = "\(prefix)- \(name) pos=(\(pos.0), \(pos.1)) size=(\(size.0), \(size.1))\n"
        for child in children {
            result += child.dump(indent: indent + 1)
        }
        return result
    }
}

@resultBuilder
struct ExpectedTreeBuilder {
    static func buildBlock(_ components: ExpectedNode...) -> [ExpectedNode] { components }
}

func ExpectTree(@ExpectedTreeBuilder builder: () -> [ExpectedNode]) -> String {
    builder().map { $0.dump() }.joined()
}

func ExpectNode(_ name: String, x: Float, y: Float, w: Float, h: Float, @ExpectedTreeBuilder children: () -> [ExpectedNode] = { [] }) -> ExpectedNode {
    ExpectedNode(name: name, pos: (x, y), size: (w, h), children: children())
}

@Suite("Layout Tests")
struct LayoutTests {
    @Test("Layout propagation and recalculation")
    @MainActor
    func testLayout() {
        @Signal var w: Float = 213
        
        let runtime = runApp(size: SIMD2(800, 600)) {
            Row {
                Box(alignment: .center) {
                    Box()
                        .width(w)
                        .height(67)
                }
                .fillMaxHeight()
                .width(400)

                Column {
                    Box()
                        .fillMaxWidth()
                        .height(67)
                }
            }
            .fillMaxSize()
        }

        runtime.flushOnFrame()
        
        let expectedBefore = ExpectTree {
            ExpectNode("RootNode", x: 0.0, y: 0.0, w: 800.0, h: 600.0) {
                ExpectNode("RowNode", x: 0.0, y: 0.0, w: 800.0, h: 600.0) {
                    ExpectNode("BoxNode", x: 0.0, y: 0.0, w: 400.0, h: 600.0) {
                        ExpectNode("BoxNode", x: 93.5, y: 266.5, w: 213.0, h: 67.0)
                    }
                    ExpectNode("ColumnNode", x: 400.0, y: 0.0, w: 400.0, h: 67.0) {
                        ExpectNode("BoxNode", x: 0.0, y: 0.0, w: 400.0, h: 67.0)
                    }
                }
            }
        }
        
        #expect(runtime.root.dumpTree() == expectedBefore)

        // Trigger width change
        w = 500
        runtime.flushOnFrame()
        
        let expectedAfter = ExpectTree {
            ExpectNode("RootNode", x: 0.0, y: 0.0, w: 800.0, h: 600.0) {
                ExpectNode("RowNode", x: 0.0, y: 0.0, w: 800.0, h: 600.0) {
                    ExpectNode("BoxNode", x: 0.0, y: 0.0, w: 400.0, h: 600.0) {
                        ExpectNode("BoxNode", x: -50.0, y: 266.5, w: 500.0, h: 67.0)
                    }
                    ExpectNode("ColumnNode", x: 400.0, y: 0.0, w: 400.0, h: 67.0) {
                        ExpectNode("BoxNode", x: 0.0, y: 0.0, w: 400.0, h: 67.0)
                    }
                }
            }
        }
        
        #expect(runtime.root.dumpTree() == expectedAfter)
    }
}
