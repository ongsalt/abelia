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

  override func calculateChildrenConstraintsMap() -> [ObjectIdentifier: Computed<Constraints>] {
    var map: [ObjectIdentifier: Computed<Constraints>] = [:]
    let _layoutChildren = Array(layoutChildren)

    for (index, child) in _layoutChildren.enumerated() {
      map[child.id] = Computed { [unowned self] in
        let c = self.constraints
        let resolvedMaxWidth = self.preferedWidth == .infinity ? c.maxWidth : (self.preferedWidth ?? c.maxWidth)
        let resolvedMaxHeight = self.preferedHeight == .infinity ? c.maxHeight : (self.preferedHeight ?? c.maxHeight)

        var consumedWidth: Float = 0
        for i in 0..<index {
          consumedWidth += _layoutChildren[i].size.x + self.gap
        }

        let remainingWidth = max(0, resolvedMaxWidth - consumedWidth)

        return Constraints(
          minWidth: 0,
          maxWidth: remainingWidth,
          minHeight: self.verticalAlignment == .stretch ? resolvedMaxHeight : 0,
          maxHeight: resolvedMaxHeight
        )
      }
    }
    return map
  }

  override func calculateChildrenOffsetsMap() -> [ObjectIdentifier: Computed<Position<Float>>] {
    var map: [ObjectIdentifier: Computed<Position<Float>>] = [:]
    let _layoutChildren = Array(layoutChildren)
    
    for (index, child) in _layoutChildren.enumerated() {
      map[child.id] = Computed { [unowned self] in
        let totalGap = self.gap * Float(max(0, _layoutChildren.count - 1))
        
        var totalChildWidth: Float = 0
        if self.horizontalArrangement != .start {
          totalChildWidth = _layoutChildren.reduce(0) { $0 + $1.size.x } + totalGap
        }
        
        let extraSpace = max(0, self.size.x - totalChildWidth)

        var spacing: Float = self.gap
        var currentX: Float = 0

        switch self.horizontalArrangement {
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

        for i in 0..<index {
          currentX += _layoutChildren[i].size.x + spacing
        }

        let y: Float
        switch self.verticalAlignment {
        case .start, .stretch:
          y = 0
        case .center:
          y = (self.size.y - child.size.y) / 2
        case .end:
          y = self.size.y - child.size.y
        }
        
        return Position(currentX, y)
      }
    }

    return map
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

  override func calculateChildrenConstraintsMap() -> [ObjectIdentifier: Computed<Constraints>] {
    var map: [ObjectIdentifier: Computed<Constraints>] = [:]
    let _layoutChildren = Array(layoutChildren)

    for (index, child) in _layoutChildren.enumerated() {
      map[child.id] = Computed { [unowned self] in
        let c = self.constraints
        let resolvedMaxWidth = self.preferedWidth == .infinity ? c.maxWidth : (self.preferedWidth ?? c.maxWidth)
        let resolvedMaxHeight = self.preferedHeight == .infinity ? c.maxHeight : (self.preferedHeight ?? c.maxHeight)

        var consumedHeight: Float = 0
        for i in 0..<index {
          consumedHeight += _layoutChildren[i].size.y + self.gap
        }

        let remainingHeight = max(0, resolvedMaxHeight - consumedHeight)

        return Constraints(
          minWidth: self.horizontalAlignment == .stretch ? resolvedMaxWidth : 0,
          maxWidth: resolvedMaxWidth,
          minHeight: 0,
          maxHeight: remainingHeight
        )
      }
    }
    return map
  }

  override func calculateChildrenOffsetsMap() -> [ObjectIdentifier: Computed<Position<Float>>] {
    var map: [ObjectIdentifier: Computed<Position<Float>>] = [:]
    let _layoutChildren = Array(layoutChildren)
    
    for (index, child) in _layoutChildren.enumerated() {
      map[child.id] = Computed { [unowned self] in
        let totalGap = self.gap * Float(max(0, _layoutChildren.count - 1))
        
        var totalChildHeight: Float = 0
        if self.verticalArrangement != .start {
          totalChildHeight = _layoutChildren.reduce(0) { $0 + $1.size.y } + totalGap
        }
        
        let extraSpace = max(0, self.size.y - totalChildHeight)

        var spacing: Float = self.gap
        var currentY: Float = 0

        switch self.verticalArrangement {
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

        for i in 0..<index {
          currentY += _layoutChildren[i].size.y + spacing
        }

        let x: Float
        switch self.horizontalAlignment {
        case .start, .stretch:
          x = 0
        case .center:
          x = (self.size.x - child.size.x) / 2
        case .end:
          x = self.size.x - child.size.x
        }
        
        return Position(x, currentY)
      }
    }

    return map
  }
}
