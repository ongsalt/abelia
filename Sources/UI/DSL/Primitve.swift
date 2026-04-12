protocol Primitive: View {

}

// those inherit view should manage it own backing element
// provide macro for auto conforming and generate constructor? also markshit as state?
@Autobind
public struct Text: Primitive {
    var text: Bind<String>

    // this is by the component macro
    public init(_ text: Bind<String>) {
        self.text = text

        Effect {
            print("text: \(text.value)")
        }
    }
}

public struct Container<T: View>: Primitive {
    let children: T

    public init(@ViewBuilder body: () -> T) {
        children = body()
    }
}
