// should we do newtype


// TODO: Variadic Generics
@resultBuilder
public struct ViewBuilder {
    public static func buildBlock() -> Body {
        Body(children: [])
    }

    public static func buildBlock(_ components: any ViewProtocol...) -> Body {
        Body(children: components)
    }
}

// doing modifier here?
public struct ViewWithoutModifier: ViewProtocol {
  public let node: NonLayoutNode
  init(_ node: NonLayoutNode) {
    self.node = node
  }
}

public struct View: ViewProtocol {
  let layoutNode: LayoutNode
  public var node: NonLayoutNode {
    self.layoutNode
  }

  init(_ node: LayoutNode) {
    self.layoutNode = node
  }
}

public protocol ViewProtocol {
  var node: NonLayoutNode { get }
}

public struct Body {
  let children: [any ViewProtocol]

  var childNodes: [NonLayoutNode] {
    children.map(\.node)
  }

  public static var empty: Body {
    Body(children: [])
  }
}
