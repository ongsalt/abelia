protocol CompositionObject {
  
}

// provide stable identity
protocol ShapeGroupOwner: Identifiable {
  func withShapes<T>(_ body: (Span<ShapeMergingInstruction>) -> T) -> T
}