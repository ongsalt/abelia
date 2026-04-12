// @MainActor
// class UIRuntime {
//     let rootLayer: Layer
//     let rootElement: UIElement

//     init(layer: Layer, element: UIElement) {
//         self.rootLayer = layer
//         self.rootElement = element
//     }

//     func start() {
//         rootElement.parentData = ParentData(decidedSize: .zero, needRemeasure: true)
//         // rootElement.parentLayer = rootLayer
//         rootLayer.addChild(rootElement.layer)
//         let area = rootElement.measure(constraints: Constraints(size: rootLayer.bounds.size))
//         rootElement.place(area: Rect(topLeft: rootElement._offset, size: area))
//     }
// }

// /// 1. run the function (to setup signal and stuff)
// /// 2. init views return by function including child component
// ///
