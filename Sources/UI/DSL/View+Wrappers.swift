// there is no compose like modifier, only flutter like wrapper
// this is just syntax sugar

public extension View {
    func padding(_ size: Int) -> some View {
        // Margin(size) {
        //     self
        // }
        self
    }
}
