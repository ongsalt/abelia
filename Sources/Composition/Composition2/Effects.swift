// this might be dispatch to multiple shader
// one thing all of these have in common is that they require layer underneath to be rasterized
// Or we nuke this class and make this a property of a _Layer then the framework just flag it

enum ImageFilter {
    case blendMode(BlendMode)
    case gaussianBlur(radius: Float, edgeSampling: EdgeSamplingMethod = .repeat)
    case toneMap
    case material(MaterialType)  // very opinionate
    case dither
    // case custom(Shader)
}

enum EdgeSamplingMethod {
    case `repeat`
    case transparent
}

enum MaterialType {
    case idkMan
}

enum BlendMode {
    case overlay
    case multiply
    case add
    case subtract
}

