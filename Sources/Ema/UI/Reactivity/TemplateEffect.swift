// actually a computed node
// but the framework will flush it
@_spi(EmaInternal) import Reactivity

// well we dont need to do this if the compositor already expect this
// need to have node identity
@MainActor
func TemplateEffect(_ block: @escaping () -> Void) {
  let c = Computed {
    block()
  }

  Runtime.current?.runOnFrame { c.value }
  // onDestroy {
  //   c.cleanup?
  // }
}
