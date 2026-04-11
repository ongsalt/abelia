// typealias UIBox = UIElement

// extension UIElement {
//     // MARK: - Modifiers
//     // These now simply store the closure into our local properties.
//     @discardableResult
//     func withLayer(_ fn: @escaping (Layer) -> Void) -> Self {
//         // Effect {
//         fn(self.layer)
//         // }
//         return self
//     }

//     @discardableResult
//     func z(_ value: @autoclosure @escaping () -> Float) -> Self {
//         Effect { self.layer.z = value() }
//         return self
//     }

//     @discardableResult
//     func offset(_ value: @autoclosure @escaping () -> SIMD2<Float>) -> Self {
//         Effect {
//             self._offset = value()
//             self.requestReplace()
//         }
//         return self
//     }

//     @discardableResult
//     func size(_ value: @autoclosure @escaping () -> SIMD2<Float>) -> Self {
//         Effect {
//             let size = value()
//             self._width = size.x
//             self._height = size.y
//             self.requestRelayout()
//         }
//         return self
//     }

//     @discardableResult
//     func size(width: @autoclosure @escaping () -> Float, height: @autoclosure @escaping () -> Float)
//         -> Self
//     {
//         Effect {
//             self._width = width()
//             self._height = height()
//             self.requestRelayout()
//         }
//         return self
//     }

//     @discardableResult
//     func scale(_ value: @autoclosure @escaping () -> Float) -> Self {
//         Effect { self.layer.scale = value() }
//         return self
//     }

//     @discardableResult
//     func rotation(_ value: @autoclosure @escaping () -> Float) -> Self {
//         Effect { self.layer.rotation = value() }
//         return self
//     }

//     @discardableResult
//     func opacity(_ value: @autoclosure @escaping () -> Float) -> Self {
//         Effect { self.layer.opacity = value() }
//         return self
//     }

//     @discardableResult
//     func hidden(_ value: @autoclosure @escaping () -> Bool) -> Self {
//         Effect { self.layer.isHidden = value() }
//         return self
//     }

//     @discardableResult
//     func mask(_ value: @autoclosure @escaping () -> Layer?) -> Self {
//         Effect { self.layer.mask = value() }
//         return self
//     }

//     @discardableResult
//     func clipChildren(_ value: @autoclosure @escaping () -> Bool) -> Self {
//         Effect { self.layer.clipChildren = value() }
//         return self
//     }

//     @discardableResult
//     func cornerRadius(_ value: @autoclosure @escaping () -> Float) -> Self {
//         Effect { self.layer.cornerRadius = value() }
//         return self
//     }

//     @discardableResult
//     func cornerDegree(_ value: @autoclosure @escaping () -> Float) -> Self {
//         Effect { self.layer.cornerDegree = value() }
//         return self
//     }

//     @discardableResult
//     func border(
//         width: @autoclosure @escaping () -> Float, color: @autoclosure @escaping () -> Color
//     ) -> Self {
//         Effect {
//             self.layer.borderWidth = width()
//             self.layer.borderColor = color()
//         }
//         return self
//     }

//     @discardableResult
//     func shadow(
//         color: @autoclosure @escaping () -> Color,
//         blur: @autoclosure @escaping () -> Float,
//         offset: @autoclosure @escaping () -> SIMD2<Float> = .zero
//     ) -> Self {
//         Effect {
//             self.layer.shadowColor = color()
//             self.layer.shadowBlur = blur()
//             self.layer.shadowOffset = offset()
//         }
//         return self
//     }

//     @discardableResult
//     func background(_ value: @autoclosure @escaping () -> Color) -> Self {
//         Effect { self.layer.backgroundColor = value() }
//         return self
//     }

//     @discardableResult
//     func transform(_ value: @autoclosure @escaping () -> AffineMatrix) -> Self {
//         Effect { self.layer.transformations = value() }
//         return self
//     }
// }
