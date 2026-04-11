@preconcurrency import CVMA
import Foundation
import Wayland  // for pointers

class Compositor {
    let state: VulkanState
    let pipeline: CompositePipeline
    let textureRegistry: RenderTextureRegistry

    let root: CompositionNode = CompositionNode()
    // let renderTexture: RenderTexture

    init(state: VulkanState) {
        self.state = state
        textureRegistry = RenderTextureRegistry(vulkan: state)
        pipeline = CompositePipeline(state: state, textureRegistry: textureRegistry)
    }

    func recomposite() {
        // just redraw everything ... rasterizationRoot
    }
}
