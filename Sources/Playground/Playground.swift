import Composition
import Foundation
import Reactivity
import UI

@MainActor
func Counter() -> View {
    @State
    var count = 0

    Task {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(1))
            count += 1
        }
    }

    return Row {
        Text("idk")
        Column {
            Text("count = \(count)")
        }

        Box {
            Text("Increment")
        }
        // .padding(.px(12))
        .background("red")
        .padding(12.px)
    }
}

typealias Px = Int
extension Int {
    var px: Px {
        Px(self)
    }
}

@main
struct Playground {
    public static func main() throws {
        withCompositor { compositor in
            _ = Unmanaged.passRetained(compositor)
        }
        // let node = Counter()

        // node.renderNode.print()

        // let compositor = try setupCompositor()
        // Task {
        //     while !Task.isCancelled {
        //         compositor.root.children = []
        //         for i in 0..<200 {
        //             setupScene(root: compositor.root, offset: Float(2 * i))
        //         }
        //         // await Task.yield()
        //         try await Task.sleep(for: .seconds(1))
        //     }
        // }
    }
}

@MainActor
func setupScene(root: CompositionNode, offset: Float) {
    let colors: [Color] = [
        // .red, .orange,
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown,
    ]

    for (index, c) in colors.enumerated() {
        let node = CompositionNode()
        // node.shouldRasterize = true
        node.size = [96, 96]
        node.fillColor = c
        node.position = [24 * Float(index), 24 * Float(index) + offset]
        node.cornerRadius = 24

        node.shadowBlur = 18
        node.shadowColor = .black.multiply(opacity: 0.4)

        // node.borderWidth = 0.5
        // node.borderColor = .black

        root.addChild(node)
    }
}

// Task {
// @MainActor
// func drawText(text: String, compositor: Compositor) async -> RenderTexture {
//     let (ink, logical) = compositor.textRenderer.measure(text: text)
//     // TODO: transfer this to gpu
//     let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(
//         capacity: Int(logical.height * logical.width))
//     buffer.initialize(repeating: 0)
//     _ = compositor.textRenderer.render(
//         text, to: buffer, width: logical.width, height: logical.height)

//     let texture = await compositor.textureRegistry.createStaticTexture(
//         from: buffer,
//         size: [UInt32(logical.width), UInt32(logical.height)],
//         format: .init(9)  // VK_FORMAT_R8_UNORM
//     )

//     return texture
// }

@MainActor
func makeCard(compositor: Compositor) async {
    let card = CompositionNode()
    card.size = [240, 240]
    card.fillColor = .white
    card.position = [220, 60]  // Centered-ish in the window
    card.cornerRadius = 32
    card.shadowBlur = 28
    card.shadowOffset = [0, 16]
    card.shadowColor = .black.multiply(opacity: 0.15)
    // card.scale = [1, 1.1]
    compositor.root.addChild(card)

    // // Name
    // let nameTex = await drawText(text: "asfjhisdkfuh", compositor: compositor)
    // let nameNode = CompositionNode()
    // nameNode.contents = nameTex
    // nameNode.size = SIMD2(nameTex.size)
    // nameNode.position = [(240 - Float(nameTex.size.x)) / 2, 100]  // Centered text
    // nameNode.tintColor = .black
    // nameNode.fillColor = .black.multiply(opacity: 0.5)
    // card.addChild(nameNode)
}

@MainActor
func animateRect(compositor: Compositor) {
    let node = CompositionNode()
    node.shouldRasterize = true
    node.size = [96, 96]
    node.fillColor = .red
    node.position = [0, 200]
    node.cornerRadius = 24
    node.opacity = 0
    compositor.root.addChild(node)

    let clock = ContinuousClock()
    let start = clock.now

    compositor.requestAnimationFrame { controller in
        var progress = (clock.now - start) / .milliseconds(400)
        if progress >= 1 {
            progress = 1
            controller.stop()
        }
        let animProgress = Float(1 - pow(1 - progress, 3))
        node.opacity = animProgress
        node.position.x = animProgress * 100
    }
}
