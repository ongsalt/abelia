@preconcurrency import CVMA
import Foundation
import Wayland

struct CompositeRectVertexData {
	let opacityAndScreenSize: SIMD4<Float>
	let sizing: SIMD4<Float>

	let transformC1: SIMD4<Float>
	let transformC2: SIMD4<Float>
	let transformC3: SIMD4<Float>
	let transformC4: SIMD4<Float>

	let cornerRadius: SIMD4<Float>
	let cornerDegreeAndBorderWidthAndVertexPos: SIMD4<Float>

	let fillColor: SIMD4<Float>
	let borderColor: SIMD4<Float>
	let shadowColor: SIMD4<Float>
	let shadow: SIMD4<Float>

	let contents: SIMD4<UInt32>
	let nineGrid: SIMD4<Float>

	init(
		opacity: Float = 1,
		screenSize: SIMD2<UInt32>,
		position: SIMD2<Float>,
		size: SIMD2<Float>,
		vertexPos: SIMD2<Float>,
		transform: AffineMatrix = .identity,
		cornerRadius: SIMD4<Float> = .zero,
		cornerDegree: Float = 0,
		borderWidth: Float = 0,
		fillColor: Color = .transparent,
		borderColor: Color = .transparent,
		shadowColor: Color = .transparent,
		shadowOffset: SIMD2<Float> = .zero,
		shadowBlur: Float = 0,
		shadowSpread: Float = 0,
		hasContent: Bool = false,
		contentIndex: UInt32 = 0,
		contentAux0: UInt32 = 0,
		contentAux1: UInt32 = 0,
		nineGrid: SIMD4<Float> = .zero
	) {
		let maxRadius = (min(size.x, size.y) / 2).max(0)
		let normalizedCornerRadius = SIMD4<Float>(
			cornerRadius.x.clamp(0, maxRadius),
			cornerRadius.y.clamp(0, maxRadius),
			cornerRadius.z.clamp(0, maxRadius),
			cornerRadius.w.clamp(0, maxRadius)
		)

		self.opacityAndScreenSize = [opacity, Float(screenSize.x), Float(screenSize.y), 0]
		self.sizing = [position.x, position.y, size.x, size.y]

		self.transformC1 = transform.c1
		self.transformC2 = transform.c2
		self.transformC3 = transform.c3
		self.transformC4 = transform.c4

		self.cornerRadius = normalizedCornerRadius
		self.cornerDegreeAndBorderWidthAndVertexPos = [
			cornerDegree,
			borderWidth,
			vertexPos.x,
			vertexPos.y,
		]

		self.fillColor = SIMD4(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
		self.borderColor = SIMD4(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
		self.shadowColor = SIMD4(shadowColor.r, shadowColor.g, shadowColor.b, shadowColor.a)
		self.shadow = [shadowOffset.x, shadowOffset.y, shadowBlur.max(0), shadowSpread]

		self.contents = [hasContent ? 1 : 0, contentIndex, contentAux0, contentAux1]
		self.nineGrid = nineGrid
	}

	init(
		opacity: Float = 1,
		screenSize: SIMD2<UInt32>,
		position: SIMD2<Float>,
		size: SIMD2<Float>,
		vertexPos: SIMD2<Float>,
		transform: AffineMatrix = .identity,
		cornerRadius: Float,
		cornerDegree: Float = 0,
		borderWidth: Float = 0,
		fillColor: Color = .transparent,
		borderColor: Color = .transparent,
		shadowColor: Color = .transparent,
		shadowOffset: SIMD2<Float> = .zero,
		shadowBlur: Float = 0,
		shadowSpread: Float = 0,
		hasContent: Bool = false,
		contentIndex: UInt32 = 0,
		contentAux0: UInt32 = 0,
		contentAux1: UInt32 = 0,
		nineGrid: SIMD4<Float> = .zero
	) {
		let radii = SIMD4<Float>(repeating: cornerRadius)
		self.init(
			opacity: opacity,
			screenSize: screenSize,
			position: position,
			size: size,
			vertexPos: vertexPos,
			transform: transform,
			cornerRadius: radii,
			cornerDegree: cornerDegree,
			borderWidth: borderWidth,
			fillColor: fillColor,
			borderColor: borderColor,
			shadowColor: shadowColor,
			shadowOffset: shadowOffset,
			shadowBlur: shadowBlur,
			shadowSpread: shadowSpread,
			hasContent: hasContent,
			contentIndex: contentIndex,
			contentAux0: contentAux0,
			contentAux1: contentAux1,
			nineGrid: nineGrid
		)
	}

	static let bindingDescriptions: VkVertexInputBindingDescription = .init(
		binding: 0,
		stride: UInt32(MemoryLayout<Self>.stride),
		inputRate: VK_VERTEX_INPUT_RATE_VERTEX
	)

	static let attributeDescriptions: [VkVertexInputAttributeDescription] = [
		.init(
			location: 0,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.opacityAndScreenSize)!)
		),
		.init(
			location: 1,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.sizing)!)
		),
		.init(
			location: 2,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC1)!)
		),
		.init(
			location: 3,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC2)!)
		),
		.init(
			location: 4,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC3)!)
		),
		.init(
			location: 5,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.transformC4)!)
		),
		.init(
			location: 6,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.cornerRadius)!)
		),
		.init(
			location: 7,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.cornerDegreeAndBorderWidthAndVertexPos)!)
		),
		.init(
			location: 8,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.fillColor)!)
		),
		.init(
			location: 9,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.borderColor)!)
		),
		.init(
			location: 10,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.shadowColor)!)
		),
		.init(
			location: 11,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.shadow)!)
		),
		.init(
			location: 12,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_UINT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.contents)!)
		),
		.init(
			location: 13,
			binding: 0,
			format: VK_FORMAT_R32G32B32A32_SFLOAT,
			offset: UInt32(MemoryLayout<Self>.offset(of: \.nineGrid)!)
		),
	]
}
