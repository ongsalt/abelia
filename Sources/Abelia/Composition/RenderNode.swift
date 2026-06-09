import Vulkan

struct LayerSnapshot {

}

class RenderNode {
    var data: RenderNodeData = .zero
}

// 1 to 1 with shader data (in term of information not layout)
struct RenderNodeData: Sendable {

}

extension RenderNodeData {
    static let zero = RenderNodeData()
}

struct Matrix {}

//

class RenderNodeStorage {

}
