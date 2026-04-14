@preconcurrency import CVMA
import Foundation

protocol Pipeline {
    associatedtype DrawCommand = ()

    // take those draw commands and put it into gpu as a vertex buffer somehow
    // also draw
    func draw(commandBuffer: VkCommandBuffer, commands: [DrawCommand])
}

// so we need at least 3 kind of pipeline
// also shader rewrite