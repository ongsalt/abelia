@preconcurrency import CVulkan

public protocol LayerContents {
    // we want to put an image in here somehow
    // func
    var renderTexture: RenderTexture { get }
}

extension RenderTexture: LayerContents {
    public var renderTexture: RenderTexture { self }
}

func putLayerContent() {
    // create a view and put its in the sampler registry
}
