public struct Color: Sendable {
  public var red: Float
  public var green: Float
  public var blue: Float
  public var alpha: Float = 1.0
  public var colorSpace: ColorSpace = .srgb

  public init(
    _ colorSpace: ColorSpace = .srgb, red: Float, green: Float, blue: Float, alpha: Float = 1.0,
  ) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
    self.colorSpace = colorSpace
  }

  var asTuple: (Float, Float, Float, Float) {
    (red, green, blue, alpha)
  }

  var asPremultiplied: Color {
    Color(
      colorSpace,
      red: red * alpha,
      green: green * alpha,
      blue: blue * alpha,
      alpha: alpha,
    )
  }
}

public enum ColorSpace: Sendable {
  case srgb
  case displayP3
  // cielab???
}

extension Color {
  public init(hex rgb: UInt32, alpha: Float = 1.0) {
    let r = Float((rgb >> 16) & 0xFF) / 255.0
    let g = Float((rgb >> 8) & 0xFF) / 255.0
    let b = Float((rgb >> 0) & 0xFF) / 255.0
    self = Color(red: r, green: g, blue: b, alpha: 1.0)
  }
}

extension Color {
  public static let transparent = Color(hex: 0x000000, alpha: 0.0)
  public static let black = Color(hex: 0x000000)
  public static let white = Color(hex: 0xFFFFFF)

  // Apple Human Interface Guidelines Colors
  public static let red = Color(hex: 0xFF383C)
  public static let orange = Color(hex: 0xFF8D28)
  public static let yellow = Color(hex: 0xFFCC00)
  public static let green = Color(hex: 0x34C759)
  public static let mint = Color(hex: 0x00C8B3)
  public static let teal = Color(hex: 0x00C3D0)
  public static let cyan = Color(hex: 0x00C0E8)
  public static let blue = Color(hex: 0x0088FF)
  public static let indigo = Color(hex: 0x6155F5)
  public static let purple = Color(hex: 0xCB30E0)
  public static let pink = Color(hex: 0xFF2D55)
  public static let brown = Color(hex: 0xAC7F5E)
}
