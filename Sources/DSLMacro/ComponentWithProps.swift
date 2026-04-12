import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

struct ComponentWithPropsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws(ComponentMacroError) -> [DeclSyntax] {
        var bindings: [PatternBindingListSyntax.Element] = []
        // find every props
        for member in declaration.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            let isBinding = variable.attributes.contains { attr in
                guard let attr = attr.as(AttributeSyntax.self) else {
                    return false
                }

                return "\(attr.attributeName)" == "Props"
            }

            if !isBinding {
                continue
            }

            // TODO: support multiple binding??
            if variable.bindings.count != 1 {
                continue
            }

            let v = variable.bindings.first!
            bindings.append(v)
        }

        var params: String = ""
        var variableWithNoType: [String] = []
        for v in bindings {
            let name = v.pattern.cast(IdentifierPatternSyntax.self).identifier
            // well what if there is no type annotation
            guard let ty = v.typeAnnotation else {
                variableWithNoType.append(name.text)
                continue
            }
            params += "\(name): @escaping @autoclosure () -> \(ty.type), "
        }

        if !variableWithNoType.isEmpty {
            throw .propsNoType(names: variableWithNoType)
        }

        let body = bindings.map { v in
            let name = v.pattern.cast(IdentifierPatternSyntax.self).identifier

            // self.$text = ReadOnlyBinding(getter: text)
            return "self.$\(name) = ReadOnlyBinding(getter: \(name))"
        }.joined(separator: "\n")

        return [
            """
            public init(\(raw: params)) {
                \(raw: body)

                self.setup()
            }
            """
        ]
    }
}

enum ComponentMacroError: Error {
    case propsNoType(names: [String])
    case ellipsisFound
}

struct ComponentMacroErrorReport: Error {
    let errors: [ComponentMacroError]
}


