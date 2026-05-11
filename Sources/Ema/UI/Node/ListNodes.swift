import EmaCore
import Reactivity

public enum MainAxisAlignment {
  case start, center, end, spaceBetween, spaceAround, spaceEvenly
}

public enum CrossAxisAlignment {
  case start, center, end, stretch
}

public class RowNode: LayoutNode {
  @Signal
  public var horizontalArrangement: MainAxisAlignment = .start
  
  @Signal
  public var verticalAlignment: CrossAxisAlignment = .start

  @Signal
  public var gap: Float = 0

  override func calculateSize() -> Size<Float> {
    let _layoutChildren = Array(layoutChildren)
    let totalGap = gap * Float(max(0, _layoutChildren.count - 1))
    
    let width = preferedWidth ?? (_layoutChildren.reduce(0) { $0 + $1.size.x } + totalGap)
    let height = preferedHeight ?? (_layoutChildren.reduce(0) { max($0, $1.size.y) })
    
    return SIMD2(width, height)
  }

  override func calculateChildrenConstraints() -> [ObjectIdentifier: Constraints] {
    var childrenConstraints: [ObjectIdentifier: Constraints] = [:]
    let c = self.constraints

    let resolvedMaxWidth = preferedWidth == .infinity ? c.maxWidth : (preferedWidth ?? c.maxWidth)
    let resolvedMaxHeight = preferedHeight == .infinity ? c.maxHeight : (preferedHeight ?? c.maxHeight)

    for child in layoutChildren {
      childrenConstraints[child.id] = Constraints(
        minWidth: 0,
        maxWidth: resolvedMaxWidth,
        minHeight: verticalAlignment == .stretch ? resolvedMaxHeight : 0,
        maxHeight: resolvedMaxHeight
      )
    }
    return childrenConstraints
  }

  override func calculateChildrenOffsets() -> [ObjectIdentifier: Position<Float>] {
    var offsets: [ObjectIdentifier: Position<Float>] = [:]
    let _layoutChildren = Array(layoutChildren)
    
    let totalGap = gap * Float(max(0, _layoutChildren.count - 1))
    let totalChildWidth = _layoutChildren.reduce(0) { $0 + $1.size.x } + totalGap
    let extraSpace = max(0, self.size.x - totalChildWidth)

    var spacing: Float = gap
    var currentX: Float = 0

    switch horizontalArrangement {
    case .start:
      currentX = 0
    case .center:
      currentX = extraSpace / 2
    case .end:
      currentX = extraSpace
    case .spaceBetween:
      let extraSpacing = _layoutChildren.count > 1 ? extraSpace / Float(_layoutChildren.count - 1) : 0
      spacing += extraSpacing
    case .spaceAround:
      let extraSpacing = _layoutChildren.count > 0 ? extraSpace / Float(_layoutChildren.count) : 0
      currentX = extraSpacing / 2
      spacing += extraSpacing
    case .spaceEvenly:
      let extraSpacing = _layoutChildren.count > 0 ? extraSpace / Float(_layoutChildren.count + 1) : 0
      currentX = extraSpacing
      spacing += extraSpacing
    }

    for c in _layoutChildren {
      let y: Float
      switch verticalAlignment {
      case .start, .stretch:
        y = 0
      case .center:
        y = (self.size.y - c.size.y) / 2
      case .end:
        y = self.size.y - c.size.y
      }
      
      offsets[c.id] = Position(currentX, y)
      currentX += c.size.x + spacing
    }

    return offsets
  }
}

public class ColumnNode: LayoutNode {
  @Signal
  public var verticalArrangement: MainAxisAlignment = .start
  
  @Signal
  public var horizontalAlignment: CrossAxisAlignment = .start

  @Signal
  public var gap: Float = 0

  override func calculateSize() -> Size<Float> {
    let _layoutChildren = Array(layoutChildren)
    let totalGap = gap * Float(max(0, _layoutChildren.count - 1))
    
    let width = preferedWidth ?? (_layoutChildren.reduce(0) { max($0, $1.size.x) })
    let height = preferedHeight ?? (_layoutChildren.reduce(0) { $0 + $1.size.y } + totalGap)
    
    return SIMD2(width, height)
  }

  override func calculateChildrenConstraints() -> [ObjectIdentifier: Constraints] {
    var childrenConstraints: [ObjectIdentifier: Constraints] = [:]
    let c = self.constraints

    let resolvedMaxWidth = preferedWidth == .infinity ? c.maxWidth : (preferedWidth ?? c.maxWidth)
    let resolvedMaxHeight = preferedHeight == .infinity ? c.maxHeight : (preferedHeight ?? c.maxHeight)

    for child in layoutChildren {
      childrenConstraints[child.id] = Constraints(
        minWidth: horizontalAlignment == .stretch ? resolvedMaxWidth : 0,
        maxWidth: resolvedMaxWidth,
        minHeight: 0,
        maxHeight: resolvedMaxHeight
      )
    }
    return childrenConstraints
  }

  override func calculateChildrenOffsets() -> [ObjectIdentifier: Position<Float>] {
    var offsets: [ObjectIdentifier: Position<Float>] = [:]
    let _layoutChildren = Array(layoutChildren)
    
    let totalGap = gap * Float(max(0, _layoutChildren.count - 1))
    let totalChildHeight = _layoutChildren.reduce(0) { $0 + $1.size.y } + totalGap
    let extraSpace = max(0, self.size.y - totalChildHeight)

    var spacing: Float = gap
    var currentY: Float = 0

    switch verticalArrangement {
    case .start:
      currentY = 0
    case .center:
      currentY = extraSpace / 2
    case .end:
      currentY = extraSpace
    case .spaceBetween:
      let extraSpacing = _layoutChildren.count > 1 ? extraSpace / Float(_layoutChildren.count - 1) : 0
      spacing += extraSpacing
    case .spaceAround:
      let extraSpacing = _layoutChildren.count > 0 ? extraSpace / Float(_layoutChildren.count) : 0
      currentY = extraSpacing / 2
      spacing += extraSpacing
    case .spaceEvenly:
      let extraSpacing = _layoutChildren.count > 0 ? extraSpace / Float(_layoutChildren.count + 1) : 0
      currentY = extraSpacing
      spacing += extraSpacing
    }

    for c in _layoutChildren {
      let x: Float
      switch horizontalAlignment {
      case .start, .stretch:
        x = 0
      case .center:
        x = (self.size.x - c.size.x) / 2
      case .end:
        x = self.size.x - c.size.x
      }
      
      offsets[c.id] = Position(x, currentY)
      currentY += c.size.y + spacing
    }

    return offsets
  }
}
