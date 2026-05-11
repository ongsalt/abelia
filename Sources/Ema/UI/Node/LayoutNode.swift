// yep this is Compose's LayoutNode

// what if we do a reactive graph
// parent:constraints ->
//     -> child size  -> size -> parent:position, parent:size -> drawCommand

// its a box

// protocol Layoutable {
//   func calculateChildrenConstraints(constraints: Constraints, children: [LayoutNode])
//     -> [ObjectIdentifier: Constraints]
//   func calculateChildrenOffsets() -> [ObjectIdentifier: Position<Float>]
// }

import EmaCore

import Reactivity

public class NonLayoutNode: Identifiable {
  // MARL: Tree
  @Signal
  var parent: NonLayoutNode?

  @Signal
  private(set) var children: [NonLayoutNode] = []

  public init() {}

  public func appendChild(_ node: NonLayoutNode, after position: Int? = nil) {
    // self.renderNode.addChild(node.renderNode)
    if let position {
      children.insert(node, at: position)
    } else {
      children.append(node)
    }

    node.parent = self
  }

  public func appendChildren(_ children: some Sequence<NonLayoutNode>) {
    // self.renderNode.addChild(node.renderNode)
    for c in children {
      self.appendChild(c)
    }
  }

  public func removeChild(child: NonLayoutNode) {
    self.children.removeAll { $0.id == child.id }
    child.parent = nil
  }

  public func removeAllChild() {
    for c in self.children {
      c.parent = nil
    }
    self.children.removeAll(keepingCapacity: true)
  }

  var layoutChildren: [LayoutNode] { _layoutChildren.value }
  lazy var _layoutChildren: Computed<[LayoutNode]> = Computed { [unowned self] in
    self.children.flatMap { c in
      if let layoutNode = c as? LayoutNode {
        return [layoutNode]
      } else {
        return c.layoutChildren
      }
    }
  }

  var layoutParent: LayoutNode? { _layoutParent.value }
  lazy var _layoutParent: Computed<LayoutNode?> = Computed { [unowned self] in
    var p = self.parent
    while p != nil {
      if let layoutNode = p as? LayoutNode { return layoutNode }
      p = p?.parent
    }
    return nil
  }
}
public class LayoutNode: NonLayoutNode {
  // MARK: properties
  @Signal
  var offset: Position<Float> = .zero

  @Signal
  var preferedWidth: Float?

  @Signal
  var preferedHeight: Float?

  // MARK: Computed properties
  var constraints: Constraints { _constraints.value }
  lazy var _constraints: Computed<Constraints> = Computed { [unowned self] in
    // if parent did not exist, this node is either root or an orphan
    // i will provide a subclass RootNode to override this behavior
    layoutParent?.childrenConstraints[self.id] ?? Constraints.infinity
  }

  // depends on parent exposed constrants
  var size: Size<Float> { _size.value }
  lazy var _size: Computed<Size<Float>> = Computed { [unowned self] in
    // fill available by default ??
    // print("\(self)'s constrains: \(constraints)")
    return constraints.clamp(calculateSize())
  }

  func calculateSize() -> Size<Float> {
    return SIMD2(preferedWidth ?? 0, preferedHeight ?? 0)
  }

  // depends on parent decision
  var absolutePosition: Position<Float> { _absolutePosition.value }
  lazy var _absolutePosition: Computed<Position<Float>> = Computed { [unowned self] in
    // print("layoutParent = \(layoutParent)")
    // print("layoutParent?.childrenOffset = \(layoutParent?.childrenOffset)")
    return (layoutParent?.childrenOffset[self.id] ?? .zero) + offset
  }

  // depends on children size
  var childrenConstraints: [ObjectIdentifier: Constraints] { _childrenConstraints.value }
  lazy var _childrenConstraints: Computed<[ObjectIdentifier: Constraints]> = Computed {
    [unowned self] in
    calculateChildrenConstraints()
  }

  // this fn will be override
  func calculateChildrenConstraints() -> [ObjectIdentifier: Constraints] {
    var childrenConstraints: [ObjectIdentifier: Constraints] = [:]
    for c in layoutChildren {
      childrenConstraints[c.id] = self.constraints
    }

    return childrenConstraints
  }

  // also depends on children size
  var childrenOffset: [ObjectIdentifier: Position<Float>] { _childrenOffset.value }
  lazy var _childrenOffset: Computed<[ObjectIdentifier: Position<Float>]> = Computed {
    [unowned self] in
    calculateChildrenOffsets()
  }

  // this fn will be override
  func calculateChildrenOffsets() -> [ObjectIdentifier: Position<Float>] {
    var childrenOffset: [ObjectIdentifier: Position<Float>] = [:]

    for c in layoutChildren {
      childrenOffset[c.id] = .zero
    }

    return childrenOffset
  }
}

public class BoxNode: LayoutNode {
  @Signal
  /// Main axis
  var alignment: BoxAlignment = .topLeft

  override func calculateChildrenOffsets() -> [ObjectIdentifier: Position<Float>] {
    var childrenOffset: [ObjectIdentifier: Position<Float>] = [:]

    for c in layoutChildren {
      switch self.alignment {
      case .topLeft:
        childrenOffset[c.id] = .zero
      case .topCenter:
        childrenOffset[c.id] = Position((self.size.x - c.size.x) / 2, 0)
      case .topRight:
        childrenOffset[c.id] = Position(self.size.x - c.size.x, 0)
      case .center:
        childrenOffset[c.id] = Position((self.size.x - c.size.x) / 2, (self.size.y - c.size.y) / 2)
      case .bottomLeft:
        childrenOffset[c.id] = Position(0, self.size.y - c.size.y)
      case .bottomCenter:
        childrenOffset[c.id] = Position((self.size.x - c.size.x) / 2, self.size.y - c.size.y)
      case .bottomRight:
        childrenOffset[c.id] = Position(self.size.x - c.size.x, self.size.y - c.size.y)
      }
    }

    return childrenOffset
  }
}
public class RootNode: BoxNode {
  override var constraints: Constraints {
    Constraints.init(size: SIMD2(self.preferedWidth!, self.preferedHeight!))
  }

  init(size: Size<Float>) {
    super.init()

    // must not be null
    self.preferedWidth = size.x
    self.preferedHeight = size.y
  }
}
public enum BoxAlignment {
  case topLeft, topCenter, topRight
  case center
  case bottomLeft, bottomCenter, bottomRight
}
extension NonLayoutNode {
  func setBody(_ body: Body) {
    self.removeAllChild()
    self.appendChildren(body.childNodes)
  }

  public func printTree(indent: Int = 0) {
    let prefix = String(repeating: "  ", count: indent)
    var info = "\(type(of: self))"
    if let layoutNode = self as? LayoutNode {
      let pos = layoutNode.absolutePosition
      let size = layoutNode.size
      info += " pos=(\(pos.x), \(pos.y)) size=(\(size.x), \(size.y))"
    }
    print("\(prefix)- \(info)")
    for child in children {
      child.printTree(indent: indent + 1)
    }
  }

}
