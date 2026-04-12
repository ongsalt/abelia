// class ZStack: UIElement {
//     private var _horizontalAlignment: CrossAxisAlignment = .start
//     private var _verticalAlignment: CrossAxisAlignment = .start

//     @discardableResult
//     func horizontalAlignment(_ value: @autoclosure @escaping () -> CrossAxisAlignment) -> Self {
//         Effect {
//             self._horizontalAlignment = value()
//             self.markChildrenNeedReplace()
//             self.requestRelayout()
//         }
//         return self
//     }

//     @discardableResult
//     func verticalAlignment(_ value: @autoclosure @escaping () -> CrossAxisAlignment) -> Self {
//         Effect {
//             self._verticalAlignment = value()
//             self.markChildrenNeedReplace()
//             self.requestRelayout()
//         }
//         return self
//     }

//     @discardableResult
//     func alignX(_ value: @autoclosure @escaping () -> CrossAxisAlignment) -> Self {
//         return horizontalAlignment(value())
//     }

//     @discardableResult
//     func alignY(_ value: @autoclosure @escaping () -> CrossAxisAlignment) -> Self {
//         return verticalAlignment(value())
//     }

//     @discardableResult
//     func alignment(
//         horizontal: @autoclosure @escaping () -> CrossAxisAlignment,
//         vertical: @autoclosure @escaping () -> CrossAxisAlignment
//     ) -> Self {
//         Effect {
//             self._horizontalAlignment = horizontal()
//             self._verticalAlignment = vertical()
//             self.markChildrenNeedReplace()
//             self.requestRelayout()
//         }
//         return self
//     }

//     private func markChildrenNeedReplace() {
//         for child in children {
//             child.parentData?.needReplace = true
//         }
//     }

//     override func measure(constraints: Constraints) -> SIMD2<Float> {
//         var w: Float = 0
//         var h: Float = 0

//         var childMin = SIMD2<Float>(0, 0)
//         var childMax = constraints.maxSize

//         if _horizontalAlignment == .stretch {
//             childMin.x = constraints.maxWidth
//             childMax.x = constraints.maxWidth
//         }

//         if _verticalAlignment == .stretch {
//             childMin.y = constraints.maxHeight
//             childMax.y = constraints.maxHeight
//         }

//         let childConstraints = Constraints(minSize: childMin, maxSize: childMax)

//         for child in children {
//             // needX is different for each container type
//             let size =
//                 if child.parentData!.needRemeasure {
//                     child.measure(constraints: childConstraints)
//                 } else {
//                     child.parentData!.decidedSize
//                 }

//             if size != child.parentData!.decidedSize {
//                 child.parentData!.needReplace = true
//             }

//             w = max(w, size.x)
//             h = max(w, size.y)

//             child.parentData!.previousConstraints = childConstraints
//             child.parentData!.decidedSize = childConstraints.clamp(size)
//             // print(child.layer.backgroundColor)
//             // print(child.parentData!)
//             child.parentData!.needRemeasure = false
//         }

//         return constraints.clamp([_width ?? w, _height ?? h])
//     }

//     override func place(area: Rect) {
//         super.place(area: area)
//         // var area = area

//         for child in children {
//             if !child.parentData!.needReplace {
//                 continue
//             }
//             let decidedSize = child.parentData!.decidedSize
//             var childWidth = decidedSize.x
//             var childHeight = decidedSize.y

//             if _horizontalAlignment == .stretch {
//                 childWidth = area.width
//             }
//             if _verticalAlignment == .stretch {
//                 childHeight = area.height
//             }

//             let offsetX: Float
//             switch _horizontalAlignment {
//             case .start, .stretch:
//                 offsetX = 0
//             case .center:
//                 offsetX = (area.width - childWidth) / 2
//             case .end:
//                 offsetX = area.width - childWidth
//             }

//             let offsetY: Float
//             switch _verticalAlignment {
//             case .start, .stretch:
//                 offsetY = 0
//             case .center:
//                 offsetY = (area.height - childHeight) / 2
//             case .end:
//                 offsetY = area.height - childHeight
//             }

//             let childArea = Rect(
//                 // topLeft: [area.left + offsetX, area.top + offsetY],
//                 topLeft: [offsetX, offsetY],
//                 size: [childWidth, childHeight]
//             )
//             child.place(area: childArea)

//             child.parentData!.finalRect = childArea
//             child.parentData!.needReplace = false
//         }
//     }
// }

// enum StackAxis {
//     case vertical
//     case horizontal
// }

// enum MainAxisAlignment {
//     case start
//     case center
//     case end
//     case spaceBetween
//     case spaceAround
//     case spaceEvenly
// }

// enum CrossAxisAlignment {
//     case start
//     case center
//     case end
//     case stretch
// }

// class Stack: UIElement {
//     private let axis: StackAxis
//     private var _mainAlignment: MainAxisAlignment = .start
//     private var _crossAlignment: CrossAxisAlignment = .start
//     private var _gap: Float = 0

//     init(axis: StackAxis) {
//         self.axis = axis
//         super.init()
//     }

//     @discardableResult
//     func mainAlignment(_ value: @autoclosure @escaping () -> MainAxisAlignment) -> Self {
//         Effect {
//             self._mainAlignment = value()
//             self.markChildrenNeedReplace()
//             self.requestRelayout()
//         }
//         return self
//     }

//     @discardableResult
//     func crossAlignment(_ value: @autoclosure @escaping () -> CrossAxisAlignment) -> Self {
//         Effect {
//             self._crossAlignment = value()
//             self.markChildrenNeedReplace()
//             self.requestRelayout()
//         }
//         return self
//     }

//     @discardableResult
//     func justify(_ value: @autoclosure @escaping () -> MainAxisAlignment) -> Self {
//         return mainAlignment(value())
//     }

//     @discardableResult
//     func align(_ value: @autoclosure @escaping () -> CrossAxisAlignment) -> Self {
//         return crossAlignment(value())
//     }

//     @discardableResult
//     func gap(_ value: @autoclosure @escaping () -> Float) -> Self {
//         Effect {
//             self._gap = value()
//             self.markChildrenNeedReplace()
//             self.requestRelayout()
//         }
//         return self
//     }

//     private func markChildrenNeedReplace() {
//         for child in children {
//             child.parentData?.needReplace = true
//         }
//     }

//     override func measure(constraints: Constraints) -> SIMD2<Float> {
//         var totalMain: Float = 0
//         var crossMax: Float = 0

//         var childMin = SIMD2<Float>(0, 0)
//         var childMax = constraints.maxSize

//         if _crossAlignment == .stretch {
//             switch axis {
//             case .vertical:
//                 childMin.x = constraints.maxWidth
//                 childMax.x = constraints.maxWidth
//             case .horizontal:
//                 childMin.y = constraints.maxHeight
//                 childMax.y = constraints.maxHeight
//             }
//         }

//         let childConstraints = Constraints(minSize: childMin, maxSize: childMax)

//         for child in children {
//             let size =
//                 if child.parentData!.needRemeasure {
//                     child.measure(constraints: childConstraints)
//                 } else {
//                     child.parentData!.decidedSize
//                 }

//             if size != child.parentData!.decidedSize {
//                 child.parentData!.needReplace = true
//             }

//             let decidedSize = childConstraints.clamp(size)
//             child.parentData!.previousConstraints = childConstraints
//             child.parentData!.decidedSize = decidedSize
//             child.parentData!.needRemeasure = false

//             switch axis {
//             case .vertical:
//                 totalMain += decidedSize.y
//                 crossMax = max(crossMax, decidedSize.x)
//             case .horizontal:
//                 totalMain += decidedSize.x
//                 crossMax = max(crossMax, decidedSize.y)
//             }
//         }

//         if children.count > 1 {
//             totalMain += _gap * Float(children.count - 1)
//         }

//         switch axis {
//         case .vertical:
//             return constraints.clamp([crossMax, totalMain])
//         case .horizontal:
//             return constraints.clamp([totalMain, crossMax])
//         }
//     }

//     override func place(area: Rect) {
//         super.place(area: area)

//         let mainAvailable = axis == .vertical ? area.size.y : area.size.x
//         let crossAvailable = axis == .vertical ? area.size.x : area.size.y

//         var totalMain: Float = 0
//         for child in children {
//             let size = child.parentData!.decidedSize
//             totalMain += (axis == .vertical) ? size.y : size.x
//         }

//         if children.count > 1 {
//             totalMain += _gap * Float(children.count - 1)
//         }

//         let extra = max(0, mainAvailable - totalMain)
//         let count = Float(children.count)
//         var leading: Float = 0
//         var between: Float = 0

//         switch _mainAlignment {
//         case .start:
//             leading = 0
//             between = _gap
//         case .center:
//             leading = extra / 2
//             between = _gap
//         case .end:
//             leading = extra
//             between = _gap
//         case .spaceBetween:
//             leading = 0
//             between = children.count > 1 ? _gap + (extra / Float(children.count - 1)) : 0
//         case .spaceAround:
//             between = children.isEmpty ? 0 : _gap + (extra / count)
//             leading = between / 2
//         case .spaceEvenly:
//             between = children.isEmpty ? 0 : _gap + (extra / (count + 1))
//             leading = between
//         }

//         var cursor = leading

//         for child in children {
//             if !child.parentData!.needReplace {
//                 cursor += (axis == .vertical ? child.parentData!.decidedSize.y : child.parentData!.decidedSize.x) + between
//                 continue
//             }

//             let decidedSize = child.parentData!.decidedSize
//             var childMain = axis == .vertical ? decidedSize.y : decidedSize.x
//             var childCross = axis == .vertical ? decidedSize.x : decidedSize.y

//             if _crossAlignment == .stretch {
//                 childCross = crossAvailable
//             }

//             let crossOffset: Float
//             switch _crossAlignment {
//             case .start, .stretch:
//                 crossOffset = 0
//             case .center:
//                 crossOffset = (crossAvailable - childCross) / 2
//             case .end:
//                 crossOffset = crossAvailable - childCross
//             }

//             let topLeft: SIMD2<Float>
//             let size: SIMD2<Float>

//             if axis == .vertical {
//                 topLeft = [area.left + crossOffset, area.top + cursor]
//                 size = [childCross, childMain]
//             } else {
//                 topLeft = [area.left + cursor, area.top + crossOffset]
//                 size = [childMain, childCross]
//             }

//             let childArea = Rect(topLeft: topLeft, size: size)
//             child.place(area: childArea)
//             child.parentData!.finalRect = childArea
//             child.parentData!.needReplace = false

//             cursor += childMain + between
//         }
//     }
// }

// class VStack: Stack {
//     convenience init(
//         main: @autoclosure @escaping () -> MainAxisAlignment = .start,
//         cross: @autoclosure @escaping () -> CrossAxisAlignment = .start,
//         gap: @autoclosure @escaping () -> Float = 0,
//         @ViewBuilder children: () -> View
//     ) {
//         self.init(axis: .vertical)
//         addChild(children())
//         mainAlignment(main())
//         crossAlignment(cross())
//         self.gap(gap())
//     }
// }

// class HStack: Stack {
//     convenience init(
//         main: @autoclosure @escaping () -> MainAxisAlignment = .start,
//         cross: @autoclosure @escaping () -> CrossAxisAlignment = .start,
//         gap: @autoclosure @escaping () -> Float = 0,
//         @ViewBuilder children: () -> View
//     ) {
//         self.init(axis: .horizontal)
//         addChild(children())
//         mainAlignment(main())
//         crossAlignment(cross())
//         self.gap(gap())
//     }
// }