class Compositor {
    // private(set) var root: RootLayer!

    var dirtyLayers: [Layer] = []
    var dirtyLayerIds: Set<ObjectIdentifier> = []

    func markDirty(_ layer: Layer, accumulated: Bool = false, shouldRecreateSwapchain: Bool = false)
    {
        let (inserted, _) = dirtyLayerIds.insert(layer.id)
        if inserted {
            dirtyLayers.append(layer)
        }

        if accumulated {
            for c in layer.children {
                markDirty(c, accumulated: true)
            }
        }

        // tell renderer we need rerender
        // renderer.markRerenderNeeded(shouldRecreateSwapchain: shouldRecreateSwapchain)
    }
}
