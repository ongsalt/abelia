import Composition

@MainActor
public class Element: Identifiable {
    // var parentData: ParentData? = nil
    unowned var parent: Element? = nil
    private var _children: [Element] = []

    public var style: Style = .empty
    
    private(set) public var renderNode: RenderNode?

    public func appendChild(_ element: Element, after position: Int? = nil) {
        if let position {
            _children.insert(element, at: position)
        } else {
            _children.append(element)
        }

        element.parent = self
        // element.parentData = ParentData()
    }

    public func removeChild(child: Element) {
        self._children.removeAll { $0.id == child.id }
        child.parent = nil
    }

    // layouting stuff?
}

extension Element {
    func appendChild(_ elements: some Sequence<Element>) {
        for e in elements {
            appendChild(e)
        }
    }
}

public class TextElement: Element {}
public class DivElement: Element {}

// we gonna have `eventTree`/`focusTree`/`accessibilityTree` at this level?
// chain of ui responder?

// // gonna treat this as sequence of node
// class FragmentElement: Element {

// }

// box and text
// @MainActor
// class UIElement: Identifiable {
//     unowned var parent: UIElement? = nil

//     var parentData: ParentData? = nil
//     var children: [UIElement] = []

//     var _width: Float? = nil
//     var _height: Float? = nil
//     var _offset: SIMD2<Float> = .zero

//     func measure(constraints: Constraints) -> SIMD2<Float> {
//         constraints.clamp([_width ?? 0, _height ?? 0])
//     }

//     /// aka draw
//     /// area is not layer size
//     func place(area: Rect) {
//         layer.position = area.topLeft + _offset
//         layer.bounds.size = area.size
//     }

//     func requestRelayout() {
//         // print("whattt")
//         self.parent?.relayout(child: self)
//     }

//     func requestReplace() {
//         self.parent?.replace(child: self)
//     }

//     func relayout(child: UIElement) {
//         // if self size is change then notify parent
//         // tell parent to reMeasure
//         // TODO: think what needed to trigger relayout, what can be update directly
//         // print("relayouting")
//         child.parentData!.needRemeasure = true
//         child.parentData!.needReplace = true
//         let previousSize = child.parentData!.decidedSize
//         let newSize = child.measure(constraints: child.parentData!.previousConstraints)

//         // go up until non changed area then replace
//         if previousSize != newSize {
//             requestRelayout()
//         } else {
//             replace(child: child)
//         }
//     }

//     /// Place again
//     func replace(child: UIElement) {
//         child.parentData!.needReplace = true
//         child.place(area: child.parentData!.finalRect)
//     }

//     func appendChild(_ view: View) {
//         for e in view.build() {
//             appendChild(element: e)
//         }
//     }

//     func appendChild(_ elements: some Sequence<UIElement>) {
//         for e in elements {
//             appendChild(element: e)
//         }
//     }

//     func appendChild(element: UIElement, after position: Int? = nil) {
//         if let position {
//             children.insert(element, at: position)
//         } else {
//             children.append(element)
//         }

//         element.parent = self
//         element.parentData = ParentData()
//         element.parentLayer = self.layer
//         self.layer.appendChild(element.layer)

//         // TODO: trigger onmount
//     }

//     func removeFromParent() {
//         guard let index = parent?.children.firstIndex(of: self) else {
//             return
//         }

//         parent!.children.remove(at: index)
//         parentLayer!.removeChild(layer)

//         parent = nil
//         parentData = nil
//         parentLayer = nil

//         // TODO: trigger onremove
//     }
// }

// extension UIElement: Equatable {
//     nonisolated static func == (lhs: UIElement, rhs: UIElement) -> Bool {
//         lhs.id == rhs.id
//     }
// }

// struct ParentData {
//     var decidedSize: SIMD2<Float> = .zero
//     var finalRect: Rect = .zero
//     var previousConstraints: Constraints = .zero
//     var needRemeasure: Bool = true
//     var needReplace: Bool = true
// }
