@Component
public func Box(
  alignment: Prop<BoxAlignment> = .default(.center), 
  @ViewBuilder body: () -> Body = { .empty }
)
  -> View
{
  let node = BoxNode()
  TemplateEffect { node.alignment = alignment.value }

  node.replaceChildren(body)
  return View(node)
}

@Component
public func Row(
  horizontalArrangement: Prop<MainAxisAlignment> = .default(.start),
  verticalAlignment: Prop<CrossAxisAlignment> = .default(.start),
  gap: Prop<Float> = .default(0),
  @ViewBuilder body: () -> Body = { .empty }
) -> View {
  let node = RowNode()
  TemplateEffect { node.horizontalArrangement = horizontalArrangement.value }
  TemplateEffect { node.verticalAlignment = verticalAlignment.value }
  TemplateEffect { node.gap = gap.value }

  node.replaceChildren(body)
  return View(node)
}

@Component
public func Column(
  verticalArrangement: Prop<MainAxisAlignment> = .default(.start),
  horizontalAlignment: Prop<CrossAxisAlignment> = .default(.start),
  gap: Prop<Float> = .default(0),
  @ViewBuilder body: () -> Body = { .empty }
) -> View {
  let node = ColumnNode()
  TemplateEffect { node.verticalArrangement = verticalArrangement.value }
  TemplateEffect { node.horizontalAlignment = horizontalAlignment.value }
  TemplateEffect { node.gap = gap.value }

  node.replaceChildren(body)
  return View(node)
}
