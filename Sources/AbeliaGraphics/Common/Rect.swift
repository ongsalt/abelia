public struct Rect: Sendable {
    public static let zero = Rect(top: 0, left: 0, width: 0, height: 0)
    public static let one = Rect(top: 1, left: 1, width: 1, height: 1)
    public static let unit = one

    public var top: Float
    public var left: Float
    public var width: Float
    public var height: Float

    public init(
        top: Float, left: Float, width: Float, height: Float
    ) {
        self.top = top
        self.left = left
        self.width = width
        self.height = height
    }

    public init(
        topLeft: SIMD2<Float>, size: SIMD2<Float>
    ) {
        self.top = topLeft.y
        self.left = topLeft.x
        self.width = size.x
        self.height = size.y
    }

    public init(
        center: SIMD2<Float>, size: SIMD2<Float>
    ) {
        self.top = center.y - size.y / 2
        self.left = center.x - size.x / 2
        self.width = size.x
        self.height = size.y
    }

    public var right: Float {
        get {
            left + width
        }
        set {
            width = newValue - left
        }
    }

    public var bottom: Float {
        get {
            top + height
        }
        set {
            height = newValue - bottom
        }
    }

    public var center: SIMD2<Float> {
        SIMD2(left + width / 2, top + height / 2)
    }

    public var topLeft: SIMD2<Float> {
        get {
            SIMD2(left, top)
        }
        set {
            left = newValue.x
            top = newValue.y
        }
    }

    public var size: SIMD2<Float> {
        get {
            SIMD2(width, height)
        }
        set {
            width = newValue.x
            height = newValue.y
        }
    }

    public var atOrigin: Rect {
        Rect(top: 0, left: 0, width: width, height: height)
    }

    public func padded(_ amount: Float) -> Rect {
        Rect(
            top: top - amount, left: left - amount, width: width + 2 * amount,
            height: height + 2 * amount
        )
    }

    public func offset(_ offset: SIMD2<Float>) -> Rect {
        Rect(top: top + offset.y, left: left + offset.x, width: width, height: height)
    }

    public func contains(_ position: (Float, Float)) -> Bool {
        let (x, y) = position
        return x >= left && x <= left + width && y >= top && y <= top + height
    }

    public func overlap(with other: borrowing Rect) -> Bool {
        let b = other.bottom
        let t = other.top
        let l = other.left

        return (self.left < other.right || self.right < l)
            && (self.top < b || self.bottom < t)
    }
}


extension Rect: CustomStringConvertible {
    public var description: String {
        "Rect(\(top), \(left), \(width), \(height))"
    }
}

extension Rect: Equatable {}