@resultBuilder
public struct ViewBuilder {
  public static func buildBlock() -> Body {
    Body(children: [])
  }

  public static func buildBlock(_ components: any ViewProtocol...) -> Body {
    Body(children: components)
  }
}
public struct ViewWithoutModifier: ViewProtocol {
  public let nodes: [NonLayoutNode]
  init(_ node: NonLayoutNode) {
    self.nodes = [node]
  }
}
public struct View: ViewProtocol {
  let layoutNode: LayoutNode
  public var nodes: [NonLayoutNode] {
    [self.layoutNode]
  }

  init(_ node: LayoutNode) {
    self.layoutNode = node
  }
}
public protocol ViewProtocol {
  var nodes: [NonLayoutNode] { get }
}
public struct Body: ViewProtocol {
  let children: [any ViewProtocol]

  public var nodes: [NonLayoutNode] {
    children.flatMap(\.nodes)
  }

  public static var empty: Body {
    Body(children: [])
  }
}
