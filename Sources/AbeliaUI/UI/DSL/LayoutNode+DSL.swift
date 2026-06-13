import Reactivity

extension NonLayoutNode {
  func replaceChildren(_ body: () -> Body) {
    let prev = NonLayoutNode.current
    defer { NonLayoutNode.current = prev }
    NonLayoutNode.current = self

    self.runtime?.flushOnDestroy(for: self)
    self.removeAllChild()

    let nodes = untrack { body().nodes }
    self.appendChildren(nodes)
  }
}
