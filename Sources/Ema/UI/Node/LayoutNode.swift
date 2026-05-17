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

@MainActor
public class NonLayoutNode: Identifiable {
  // i really need to make this @MainActor
  nonisolated(unsafe) static var current: NonLayoutNode?

  var runtime: Runtime?

  // MARL: Tree
  @Signal
  var parent: NonLayoutNode?

  @Signal
  private(set) var children: [NonLayoutNode] = []

  public init() {
    self.runtime = Runtime.current
  }

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
    layoutParent?.childrenConstraintsMap[self.id]?.value ?? Constraints.infinity
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
    return (layoutParent?.childrenOffsetMap[self.id]?.value ?? .zero) + offset
  }

  // depends on children size
  var childrenConstraintsMap: [ObjectIdentifier: Computed<Constraints>] {
    _childrenConstraintsMap.value
  }
  lazy var _childrenConstraintsMap: Computed<[ObjectIdentifier: Computed<Constraints>]> = Computed {
    [unowned self] in
    calculateChildrenConstraintsMap()
  }

  // this fn will be override
  func calculateChildrenConstraintsMap() -> [ObjectIdentifier: Computed<Constraints>] {
    var map: [ObjectIdentifier: Computed<Constraints>] = [:]
    for c in layoutChildren {
      map[c.id] = Computed { [unowned self] in self.constraints }
    }

    return map
  }

  // also depends on children size
  var childrenOffsetMap: [ObjectIdentifier: Computed<Position<Float>>] { _childrenOffsetMap.value }
  lazy var _childrenOffsetMap: Computed<[ObjectIdentifier: Computed<Position<Float>>]> = Computed {
    [unowned self] in
    calculateChildrenOffsetsMap()
  }

  // this fn will be override
  func calculateChildrenOffsetsMap() -> [ObjectIdentifier: Computed<Position<Float>>] {
    var map: [ObjectIdentifier: Computed<Position<Float>>] = [:]

    for c in layoutChildren {
      // lifetime tracking is hell
      map[c.id] = Computed { .zero }
    }

    return map
  }

  @Signal
  var layer: Layer?
  func initializeLayer() {
    // print("mounting", self.id)
    self.layer = runtime!.compositor!.createLayer()
    self.linkProperties()

    for c in layoutChildren {
      c.initializeLayer()
    }

    // this is bad
    self.layoutParent?.layer?.insert(layer!)
  }

  func linkProperties() {
    // need to bound with LayoutNode lifetime
    TemplateEffect { [weak self] in
      if let self {
        layer?.position = absolutePosition
        // print("absolutePosition = \(absolutePosition) [\(id)]")
      }
    }

    TemplateEffect { [weak self] in
      if let self {
        layer?.size = size
        // print("size = \(size) [\(id)]")
      }
    }
  }

  func detachLayer() {
    self.layer = nil

    for c in children {
      if let layoutNode = c as? LayoutNode {
        layoutNode.detachLayer()
      }
    }
  }
}
public class BoxNode: LayoutNode {
  @Signal
  /// Main axis
  var alignment: BoxAlignment = .topLeft

  override func calculateChildrenOffsetsMap() -> [ObjectIdentifier: Computed<Position<Float>>] {
    var map: [ObjectIdentifier: Computed<Position<Float>>] = [:]

    for c in layoutChildren {
      map[c.id] = Computed { [unowned self] in
        switch self.alignment {
        case .topLeft:
          return .zero
        case .topCenter:
          return Position((self.size.x - c.size.x) / 2, 0)
        case .topRight:
          return Position(self.size.x - c.size.x, 0)
        case .center:
          return Position((self.size.x - c.size.x) / 2, (self.size.y - c.size.y) / 2)
        case .bottomLeft:
          return Position(0, self.size.y - c.size.y)
        case .bottomCenter:
          return Position((self.size.x - c.size.x) / 2, self.size.y - c.size.y)
        case .bottomRight:
          return Position(self.size.x - c.size.x, self.size.y - c.size.y)
        }
      }
    }

    return map
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

  override func initializeLayer() {
    // TODO: rethink synchronization + animation frame api
    self.layer = runtime!.compositor!.createLayer()
    self.linkProperties()
    for c in layoutChildren {
      c.initializeLayer()
    }
    
    runtime!.compositor!.root.insert(layer!)
  }
}
public enum BoxAlignment {
  case topLeft, topCenter, topRight
  case center
  case bottomLeft, bottomCenter, bottomRight
}
extension NonLayoutNode {
  public func dumpTree(indent: Int = 0) -> String {
    let prefix = String(repeating: "  ", count: indent)
    var info = "\(type(of: self))"
    if let layoutNode = self as? LayoutNode {
      let pos = layoutNode.absolutePosition
      let size = layoutNode.size
      info += " pos=(\(pos.x), \(pos.y)) size=(\(size.x), \(size.y))"
    }
    var result = "\(prefix)- \(info)\n"
    for child in children {
      result += child.dumpTree(indent: indent + 1)
    }
    return result
  }

  public func printTree(indent: Int = 0) {
    print(dumpTree(indent: indent), terminator: "")
  }

}
