enum Color {
  case rgb(_ r: Float, _ g: Float, _ b: Float, _ a: Float)
  case oklch(_ l: Float, _ c: Float, _ h: Float, _ a: Float)

  public init(rgb: UInt32) {
    let r = Float((rgb >> 16) & 0xFF) / 255.0
    let g = Float((rgb >> 8) & 0xFF) / 255.0
    let b = Float((rgb >> 0) & 0xFF) / 255.0
    self = .rgb(r, g, b, 1.0)
  }
}

extension Color {
  public static let transparent = Color.rgb(0, 0, 0, 0)
  public static let black = Color(rgb: 0x000000)
  public static let white = Color(rgb: 0xFFFFFF)

  // Apple Human Interface Guidelines Colors
  public static let red = Color(rgb: 0xFF383C)
  public static let orange = Color(rgb: 0xFF8D28)
  public static let yellow = Color(rgb: 0xFFCC00)
  public static let green = Color(rgb: 0x34C759)
  public static let mint = Color(rgb: 0x00C8B3)
  public static let teal = Color(rgb: 0x00C3D0)
  public static let cyan = Color(rgb: 0x00C0E8)
  public static let blue = Color(rgb: 0x0088FF)
  public static let indigo = Color(rgb: 0x6155F5)
  public static let purple = Color(rgb: 0xCB30E0)
  public static let pink = Color(rgb: 0xFF2D55)
  public static let brown = Color(rgb: 0xAC7F5E)
  public static let gray = Color(rgb: 0x8E8E93)
}
