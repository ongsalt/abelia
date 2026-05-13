func with<T>(_ value: consuming T, apply: (inout T) -> Void) -> T {
  var v = value
  apply(&v)
  return v
}

extension Numeric where Self: Comparable {
  func clamped(_ start: Self, _ end: Self) -> Self {
    min(end, max(start, self))
  }
}

func todo<T>(_ message: String = "Todo", file: String = #file, line: Int = #line) -> T {
  fatalError("\(message) at \(file):\(line)")
}