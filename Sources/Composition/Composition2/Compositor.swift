@preconcurrency import CVMA
import Foundation
import Wayland  // for pointers

class Compositor {
    let state: VulkanState
    let renderer: Renderer
    let textureRegistry: RenderTextureRegistry

    var size: SIMD2<UInt32>

    // use the root layer with caution, some property should not be touch
    let root: CompositionNode
    // var renderTexture: RenderTexture {
    //     root.backingStores!
    // }

    init(state: VulkanState) {
        self.state = state
        self.size = state.swapChain.extent.simd2

        self.root = CompositionNode()
        self.root.shouldRasterize = true  // we shuold force this somehow
        self.root.size = SIMD2(self.size)

        self.textureRegistry = RenderTextureRegistry(vulkan: state)
        self.renderer = Renderer(state: state, textureRegistry: textureRegistry)

    }

    func recomposite() {
        // just redraw everything ... rasterizationRoot
        let batches = Batch.compute(root: root)
        Log.debug(.compositor, "batches: \(batches)")

        // try allocate backing store for each rasterization root
        // how do i resize tho
        for batch in batches {
            let root = batch.root
            let size: SIMD2<UInt32> = [UInt32(root.size.x), UInt32(root.size.y)]
            if size == .zero {
                continue
            }
            if root.backingStore == nil {
                root.backingStore = textureRegistry.newRenderTarget(size: size)
            }
            if batch.hasEffectLayer && root.backingStore2 == nil {
                root.backingStore2 = textureRegistry.newRenderTarget(size: size)
            }
        }

        for batch in batches {
            // batch.writeDrawCommands(to: VkCommandBuffer)
        }

        // Log.debug(.compositor, "\(root.backingStore?.image)")

        // present it somehow
    }
}

private func buildCommands() {

}
