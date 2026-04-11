// import Foundation

// final class Text: UIElement {
//     var text: String

//     // TODO: effect for these
//     var font: String = "Noto Sans"
//     var fontSize: Float = 14

//     var color: Color = .black


//     // TODO: AttributedString
//     init(_ text: @autoclosure @escaping () -> String, reactive: Bool = true) {
//         self.text = text()
//         super.init()
//         if reactive {
//             Effect {
//                 self.text = text()
//             }
//         }
//     }

//     private func redraw() {
        
//     }

//     private func resizeTexture() {

//     }

//     override func measure(constraints: Constraints) -> SIMD2<Float> {
//         var w: Float = 0
//         var h: Float = 0

//         // TODO: measure text

//         return constraints.clamp([w, h])
//     }

//     override func place(area: Rect) {
//         super.place(area: area)
//         // var area = area
//         // TODO: draw the text
//     }
// }

// extension Text: @MainActor ExpressibleByStringLiteral {
//     public typealias StringLiteralType = String

//     public convenience init(stringLiteral: StringLiteralType) {
//         self.init(stringLiteral, reactive: false)
//     }
// }
