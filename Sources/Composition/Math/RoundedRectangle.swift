@preconcurrency import CVMA
import Foundation
import Wayland

// TODO: refactor this to be like an enum or smth
// windows.ui.composition brush api is very nice, might rewrite 
struct RoundedRectangleDrawCommand {
    let color: [4 of Color]

    let center: SIMD2<Float>
    let size: SIMD2<Float>

    let borderRadius: Float
    let rotation: Float

    let borderWidth: Float
    let borderColor: Color
    let shadowBlur: Float
    let shadowOffset: SIMD2<Float>

    let cornerDegree: Float

    let transform: AffineMatrix

    let mode: Float

    static let indexCount: UInt32 = 4

    func toVertexData(indexOffset: UInt32 = 0) -> (vertexes: [RoundedRectangleVertexData], indexes: [UInt32]) {
        let halfSize = size / 2
        let shadowPadX = max(0, shadowBlur * 2 + abs(shadowOffset.x))
        let shadowPadY = max(0, shadowBlur * 2 + abs(shadowOffset.y))
        let quadHalfSize = halfSize + SIMD2(shadowPadX, shadowPadY)
        let vertexes = [
            center - quadHalfSize,
            SIMD2(center.x + quadHalfSize.x, center.y - quadHalfSize.y),
            center + quadHalfSize,
            SIMD2(center.x - quadHalfSize.x, center.y + quadHalfSize.y),
        ].enumerated().map { (i, vertex) in
            RoundedRectangleVertexData(
                color: SIMD4(color[i].r, color[i].g, color[i].b, color[i].a),
                sizing: SIMD4(center.x, center.y, size.x, size.y),
                borderRadiusAndRotation: SIMD4(min(borderRadius, size.min() / 2), rotation, 0, 0),
            borderWidthAndDegree: SIMD4(borderWidth, cornerDegree, 0, 0),
                borderColor: SIMD4(borderColor.r, borderColor.g, borderColor.b, borderColor.a),
                shadowParams: SIMD4(shadowOffset.x, shadowOffset.y, shadowBlur, mode),
                transformC1: transform.c1,
                transformC2: transform.c2,
                transformC3: transform.c3,
                transformC4: transform.c4,
                vertex: SIMD4(vertex.x, vertex.y, 0, 0)
            )
        }

        let indexes: [UInt32] = [indexOffset + 0, indexOffset + 1, indexOffset + 2, indexOffset + 0, indexOffset + 3, indexOffset + 2]

        return (vertexes, indexes)
    }
}

struct RoundedRectangleVertexData {
    let color: SIMD4<Float>

    let sizing: SIMD4<Float>

    let borderRadiusAndRotation: SIMD4<Float>
    let borderWidthAndDegree: SIMD4<Float>

    let borderColor: SIMD4<Float>
    let shadowParams: SIMD4<Float>

    let transformC1: SIMD4<Float>
    let transformC2: SIMD4<Float>
    let transformC3: SIMD4<Float>
    let transformC4: SIMD4<Float>

    // flag
    // let isFirstHalf: UInt32  // actuall a bool tho

    let vertex: SIMD4<Float>

    static let bindingDescriptions: VkVertexInputBindingDescription = .init(
        binding: 0,
        stride: UInt32(MemoryLayout<Self>.size),
        inputRate: VK_VERTEX_INPUT_RATE_VERTEX
    )

    static let attributeDescriptions: [VkVertexInputAttributeDescription] = [
        // Color
        .init(
            location: 0,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.color)!)
        ),
        // center, w, h
        .init(
            location: 1,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.sizing)!)
        ),
        // borderRadius, rotation
        .init(
            location: 2,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.borderRadiusAndRotation)!)
        ),
        // borderWidth, cornerDegree
        .init(
            location: 3,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.borderWidthAndDegree)!)
        ),
        // borderColor
        .init(
            location: 4,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.borderColor)!)
        ),
        // shadowOffset, shadowBlur, mode
        .init(
            location: 6,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.shadowParams)!)
        ),
        // transform c1
        .init(
            location: 9,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC1)!)
        ),
        // transform c2
        .init(
            location: 10,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC2)!)
        ),
        // transform c3
        .init(
            location: 11,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC3)!)
        ),
        // transform c4
        .init(
            location: 12,
            binding: 0,
            format: VK_FORMAT_R32G32B32A32_SFLOAT,  // 4 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC4)!)
        ),
        
        // vertex position
        .init(
            location: 7,
            binding: 0,
            format: VK_FORMAT_R32G32_SFLOAT,  // 2 float
            offset: UInt32(MemoryLayout<Self>.offset(of: \.vertex)!)
        ),

    ]

}
