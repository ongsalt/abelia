// there is no compose like modifier, only flutter like wrapper
// this is just syntax sugar

extension View {
    public func padding(_ size: Int) -> some View {
        // Margin(size) {
        //     self
        // }
        self
    }

    public func background(_ color: Any) -> some View {
        self
    }

}
