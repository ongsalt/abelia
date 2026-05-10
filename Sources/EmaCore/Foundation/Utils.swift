func with<T>(_ value: consuming T, apply: (inout T) -> Void) -> T {
  var v = value
  apply(&v)
  return v
}

