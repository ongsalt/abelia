// inspired by clay/css flex

/// also need origin/offset and tile rendering in our layer
///  > ScrollLayer?

/// Passes
/// fit -> flex grow/shrink -> text -> position
/// main.fit -> main.flex -> ratio that depends on main
/// cross.fit -> cross.flex -> ratio that depends on cross

enum Size {
  case fit
  
  // in logical px
  case fixed(Float) 

  // fraction of parent, work best when its cross axis
  case fraction(Float) 

  case flex(_ weight: Float = 1, basis: Float = 0, shrink: Float = 0)

  case ratio(Float) 
  // depends on other axis, same as text
  // text with w=.ratio in a flex-row
}

/// Sizing that are valid on text [main, cross]
/// - fixed, auto
/// - auto, fixed
/// - ratio, auto -> might overflow
/// - auto, ratio -> might overflow

/// flex wrap and masonry? 

extension Size: ExpressibleByFloatLiteral {
  typealias FloatLiteralType = Float
  init(floatLiteral value: FloatLiteralType) {
    self = .fixed(value)
  }
}

/// Edge cases
/// - fixed children larger than parent -> fuck you, do it as specified
/// - double ratio -> ignore both, print error
/// 


/// text width in -> height out OR h in -> w out
/// text flex.basis is its minimum size