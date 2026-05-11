public final class WithDeps<T> {
  public var value: T
  var deps: [AnyObject]

  public init(_ value: consuming T, deps: [AnyObject] = []) {
    self.value = value
    self.deps = deps
  }

  public func addDeps(_ other: consuming AnyObject) -> WithDeps<T> {
    self.deps.append(other)
    return self
  }
}
