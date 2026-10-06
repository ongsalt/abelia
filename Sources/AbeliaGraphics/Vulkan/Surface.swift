@preconcurrency import CVulkan

#if canImport(WaylandClient)
    import WaylandClient
#endif // canImport(WaylandClient)

public class Surface {
    var vkSurface: VkSurfaceKHR
    // let storage: SurfaceInner

    init(_ surface: VkSurfaceKHR) {
        self.vkSurface = surface
    }
}

private enum SurfaceInner {
    case wsi(WSISurface)
    case dxgi(DXGISurface)
}

private struct WSISurface {

}

private struct DXGISurface {

}
