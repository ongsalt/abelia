public class CompositionImage: CompositionTexture {
    public var index: Int {
        texture.index
    }
    let texture: RenderTexture

    init(_ texture: RenderTexture) {
        self.texture = texture
    }
}

