actor Renderer {
  private let graphicsContext: GraphicsContext
  private let surface: Surface
  private let swapchain: Swapchain
  private let compositionPipeline: CompositionPipeline

  // private let layerStorage: LayerStorage

  init(graphicsContext: GraphicsContext, surface: Surface, device: GraphicsDevice) {
    self.graphicsContext = graphicsContext
    self.surface = surface
    // TODO: swinit: expose window size
    self.swapchain = device.createSwapchain(for: surface)
    self.compositionPipeline = device.createCompositionPipeline(compatibleWith: swapchain)
  }

  func requestFrameCallback(_ block: @Sendable () async -> Void) {

  }
}
