import Reactivity

@Component
@MainActor
public func If(_ condition: Prop<Bool>, @ViewBuilder then thenBlock: @escaping () -> Body, @ViewBuilder else elseBlock: @escaping () -> Body = { .empty }) -> ViewWithoutModifier {
  // currentParent?
  let groupingNode = NonLayoutNode()

  TemplateEffect {
    groupingNode.removeAllChild()

    if (condition.value) {
      // TODO: capture onDestroy
      groupingNode.replaceChildren(thenBlock)
    } else {
      groupingNode.replaceChildren(elseBlock)
    }
  }

  return ViewWithoutModifier(groupingNode)
}
