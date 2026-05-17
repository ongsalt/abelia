import EmaCore

@Autobind
extension View {
  public consuming func width(_ w: Prop<Float?>) -> Self {
    TemplateEffect {
      layoutNode.preferedWidth = w.value
    }
    return self
  }

  public consuming func height(_ h: Prop<Float?>) -> Self {
    TemplateEffect {
      layoutNode.preferedHeight = h.value
    }
    // TODO: deregister effect on destroy
    return self
  }

  public consuming func fillMaxWidth() -> Self {
    layoutNode.preferedWidth = .infinity
    return self
  }

  public consuming func fillMaxHeight() -> Self {
    layoutNode.preferedHeight = .infinity
    return self
  }

  public consuming func fillMaxSize() -> Self {
    layoutNode.preferedWidth = .infinity
    layoutNode.preferedHeight = .infinity
    return self
  }

  public consuming func color(_ c: Prop<Color>) -> Self {
    TemplateEffect {
      layoutNode.layer?.brush = .solid(c.value)
    }
    return self
  }

}
