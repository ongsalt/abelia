protocol Primitive: View {

}

// those inherit view should manage it own backing element
// provide macro for auto conforming and generate constructor? also markshit as state?
struct Text: Primitive {
    // @Props
    // var text: String

    @Props
    var text: String
    // this is by the component macro
}

extension Text {
    init(_ text: @escaping @autoclosure () -> String) {
        self.$text = ReadOnlyBinding(getter: text)
    }
}

struct Container: Primitive {
    let children: any View

    init(@ViewBuilder body: () -> some View) {
        children = body()
    }
}
