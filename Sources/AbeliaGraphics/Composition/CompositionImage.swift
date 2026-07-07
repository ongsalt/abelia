public class CompositionImage: CompositionTexture, Equatable {
    public var index: Int {
        texture.index
    }
    let texture: RenderTexture

    init(_ texture: RenderTexture) {
        self.texture = texture
    }

    public static func == (lhs: CompositionImage, rhs: CompositionImage) -> Bool {
        lhs === rhs
    }
}
