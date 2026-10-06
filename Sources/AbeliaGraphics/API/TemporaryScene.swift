struct TemporaryScene {
    var commands: [DrawCommand] = []
}

extension TemporaryScene {
    mutating func fill(_ shape: any ShapeProtocol, with brush: any Brush) {
        commands.append(DrawCommand(shape: .sdf(shape), brush: brush))
    }

    mutating func stroke(_ shape: any ShapeProtocol, with brush: any Brush, _ stroke: Stroke = Stroke()) {
        commands.append(DrawCommand(shape: .sdf(shape), brush: brush, kind: .stroke(stroke)))
    }

    mutating func reset() {
        commands.removeAll()
    }
}

struct DrawCommand {
    var shape: Geometry
    var brush: any Brush
    var kind: Kind = .fill

    enum Kind {
        case fill
        case stroke(Stroke)
        case shadow(Shadow)
    }
}

struct Stroke {
    var width: Float = 1.0
    // join...
}

enum Geometry {
    case sdf(any ShapeProtocol)
    // case path(Path)
}

protocol Brush {}

struct ImageBrush: Brush {}
extension Color: Brush {}

public struct Shadow: Equatable {
    public var offset: SIMD2<Float> = .zero
    public var blur: Float = 48
    public var spread: Float = 0
    public var color: Color = .black
    public var opacity: Float = 0.36

    public init(
        offset: SIMD2<Float> = .zero,
        blur: Float = 48,
        spread: Float = 0,
        color: Color = .black,
        opacity: Float = 0.36,
    ) {
        self.offset = offset
        self.blur = blur
        self.spread = spread
        self.color = color
        self.opacity = opacity
    }
}
