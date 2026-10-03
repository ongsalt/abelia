public typealias PhysicalPosition = SIMD2

public enum ElementState: Sendable {
    case pressed
    case released
}

public enum MouseButton: Sendable {
    case left
    case right
    case middle
    case back
    case forward
    case other(UInt16)
}

public struct Modifiers: Sendable {
    public var shift: Bool
    public var control: Bool
    public var alt: Bool
    public var superKey: Bool

    public init(
        shift: Bool = false, control: Bool = false, alt: Bool = false, superKey: Bool = false
    ) {
        self.shift = shift
        self.control = control
        self.alt = alt
        self.superKey = superKey
    }
}

public struct KeyEvent: Sendable {
    public var physicalKey: UInt32
    public var logicalKey: UInt32
    public var text: String?
    public var state: ElementState
    public var isRepeat: Bool

    public init(
        physicalKey: UInt32, logicalKey: UInt32, text: String? = nil,
        state: ElementState, isRepeat: Bool
    ) {
        self.physicalKey = physicalKey
        self.logicalKey = logicalKey
        self.text = text
        self.state = state
        self.isRepeat = isRepeat
    }
}

public enum WindowState: Sendable {
    case normal
    case maximized
    case fullscreen
    case minimized
}

public enum WindowEvent: Sendable {
    case closeRequested
    case destroyed
    case focused(Bool)
    case stateChanged(WindowState)
    case redrawRequested
    case scaleFactorChanged(scaleFactor: Double)

    case resized(size: SIMD2<UInt32>, isFinal: Bool)
    case moved(PhysicalPosition<Int32>)

    case keyboardInput(event: KeyEvent, isSynthetic: Bool)


    // dmanip, TODO: zoom
    case pan(delta: SIMD2<Float>)

    case pointerMoved(id: UInt, position: PhysicalPosition<Double>, key: MouseButton)
    case pointerDown(id: UInt, position: PhysicalPosition<Double>, key: MouseButton)
    case pointerUp(id: UInt, position: PhysicalPosition<Double>, key: MouseButton)
}
