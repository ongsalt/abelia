import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// just generate an @autoclosure overload
// can be attach to a function or a entire DeclBlock member
// TODO: provide a way to escape it
struct AutobindMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws(AutobindMacroErrorReport) -> [DeclSyntax] {
        let isClass = declaration.as(ClassDeclSyntax.self) != nil
        let (functions, initializers) = findFunctionsAndInit(declaration)

        var out: [DeclSyntax] = []
        var errors: [ComponentMacroError] = []

        for fn in functions {
            let res = transformFunction(fn)
            switch res {
            case .success(let decl):
                if let decl {
                    out.append(DeclSyntax(decl))
                }
            case .failure(let e):
                errors.append(e)
            }
        }

        for initializer in initializers {
            let res = transformInit(initializer, isClass: isClass)
            switch res {
            case .success(let decl):
                if let decl {
                    out.append(DeclSyntax(decl))
                }
            case .failure(let e):
                errors.append(e)
            }
        }

        if !errors.isEmpty {
            throw AutobindMacroErrorReport(errors: errors)
        }

        return out
    }

    private static func findFunctionsAndInit(_ declaration: some DeclGroupSyntax) -> (
        [FunctionDeclSyntax], [InitializerDeclSyntax]
    ) {
        var functions: [FunctionDeclSyntax] = []
        var initializers: [InitializerDeclSyntax] = []
        for member in declaration.memberBlock.members {
            if let fn = member.decl.as(FunctionDeclSyntax.self) {
                functions.append(fn)
            } else if let initializer = member.decl.as(InitializerDeclSyntax.self) {
                initializers.append(initializer)
            }

        }

        return (functions, initializers)
    }

    static func transformFunction(_ decl: FunctionDeclSyntax) -> Result<
        FunctionDeclSyntax?, ComponentMacroError
    > {
        let res = transformSignature(signature: decl.signature)
        guard
            case .success((let newSignature, let bindIndices)) = res
        else {
            return .failure(res.error!)
        }

        if bindIndices.isEmpty {
            return .success(nil)
        }

        let callExpr = createCallExpression(
            name: decl.name.text, signature: decl.signature, bindIndices: bindIndices)

        // external name must be the same
        let out = FunctionDeclSyntax(
            attributes: decl.attributes.filter {
                $0.trimmedDescription != "@Autobind" && $0.trimmedDescription != "@Autobind2"
            },
            modifiers: decl.modifiers,
            name: decl.name,
            genericParameterClause: decl.genericParameterClause,
            signature: newSignature,
            genericWhereClause: decl.genericWhereClause,
        ) {
            // TODO: handle async/try codegen
            for stmt in createBody(
                callExpr,
                async: decl.signature.effectSpecifiers?.asyncSpecifier != nil,
                throws: decl.signature.effectSpecifiers?.throwsClause != nil
                    || decl.signature.effectSpecifiers?.throwsSpecifier != nil,
                return: true
            ) {
                stmt
            }

        }

        return .success(out)
    }

    private static func transformInit(_ decl: InitializerDeclSyntax, isClass: Bool = false)
        -> Result<
            InitializerDeclSyntax?, ComponentMacroError
        >
    {
        let res = transformSignature(signature: decl.signature)
        guard
            case .success((let newSignature, let bindIndices)) = res
        else {
            return .failure(res.error!)
        }

        if bindIndices.isEmpty {
            return .success(nil)
        }

        let callExpr = createCallExpression(
            name: "self.init", signature: decl.signature, bindIndices: bindIndices)

        let out = InitializerDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: "public")
                if isClass {
                    DeclModifierSyntax(name: "convenience")
                }
                // TODO: visibility
            },
            genericParameterClause: decl.genericParameterClause,
            signature: newSignature,
            genericWhereClause: decl.genericWhereClause,
        ) {
            // TODO: handle async/try codegen
            for stmt in createBody(
                callExpr,
                async: decl.signature.effectSpecifiers?.asyncSpecifier != nil,
                throws: decl.signature.effectSpecifiers?.throwsClause != nil
                    || decl.signature.effectSpecifiers?.throwsSpecifier != nil,
                return: false
            ) {
                stmt
            }
        }

        return .success(out)
    }

    private static func createCallExpression(
        name: String, signature: FunctionSignatureSyntax, bindIndices: Set<Int>
    )
        -> FunctionCallExprSyntax
    {
        let callExpr: FunctionCallExprSyntax = FunctionCallExprSyntax(
            callee: ExprSyntax("\(raw: name)")
        ) {
            for (index, p) in signature.parameterClause.parameters.enumerated() {
                let label = getOuterName(p)
                let expr =
                    if bindIndices.contains(index) {
                        ExprSyntax("Bind(getter: \(getInnerName(p)))")
                    } else {
                        ExprSyntax("\(getInnerName(p))")
                    }

                LabeledExprSyntax(
                    label: label,
                    colon: label != nil ? p.colon : nil,
                    expression: expr
                )
            }
        }

        return callExpr
    }

    private static func getInnerName(_ p: FunctionParameterListSyntax.Element) -> TokenSyntax {
        p.secondName ?? p.firstName
    }

    private static func getOuterName(_ p: FunctionParameterListSyntax.Element) -> TokenSyntax? {
        if "\(p.firstName.trimmed)" == "_" {
            nil
        } else {
            p.firstName
        }
    }

    private static func transformSignature(signature: FunctionSignatureSyntax)
        -> Result<(FunctionSignatureSyntax, bindIndices: Set<Int>), ComponentMacroError>
    {
        var bindIndices: Set<Int> = []
        var parameters: [FunctionParameterSyntax] = []
        for (index, p) in signature.parameterClause.parameters.enumerated() {
            // only if its bind
            guard let identifierType = p.type.as(IdentifierTypeSyntax.self),
                "\(identifierType.name)" == "Bind",
                let clause = identifierType.genericArgumentClause,
                let ty = clause.arguments.first
            else {
                parameters.append(p)
                continue
            }

            bindIndices.insert(index)

            if p.ellipsis != nil {
                // wtfffff
                return .failure(.ellipsisFound)
            }

            // let innerType = identifierType.genericArgumentClause?.arguments.index(at: 0)
            let newType: TypeSyntax = "@autoclosure @escaping () -> \(ty)"
            parameters.append(
                // what if its @ViewBuilder
                FunctionParameterSyntax(
                    attributes: p.attributes,
                    modifiers: p.modifiers,
                    firstName: p.firstName,
                    secondName: p.secondName,
                    type: newType,
                    trailingComma: p.trailingComma,
                    // defaultValue: p.defaultValue, // TODO: allow default value?
                )
            )
        }

        let clause = FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax(parameters))

        let out = FunctionSignatureSyntax(
            parameterClause: clause,
            effectSpecifiers: signature.effectSpecifiers,
            returnClause: signature.returnClause
        )

        return .success((out, bindIndices))
    }

    private static func createBody(
        _ expr: FunctionCallExprSyntax,
        async asy: Bool = false, throws thr: Bool = false, return ret: Bool = false
    ) -> [StmtSyntax] {
        var out = [""]
        if ret {
            out.append("return")
        }

        if thr {
            out.append("try")
        }

        if asy {
            out.append("await")
        }

        out.append("\(expr)")

        return [
            StmtSyntax(stringLiteral: out.joined(separator: " "))
        ]
    }
}

extension AutobindMacro: PeerMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let decl = declaration.as(FunctionDeclSyntax.self) else {
            return [
                "// this must be atttached to a function, a class or a struct."
            ]
        }

        let t = try transformFunction(decl).get()
        guard let t else {
            return []
        }

        return [
            DeclSyntax(t)
        ]
    }
}
