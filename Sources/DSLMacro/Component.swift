import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// just generate an @autoclosure overload
// can be attach to a function or a entire DeclBlock member
// TODO: provide a way to escape it
struct ComponentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws(ComponentMacroErrorReport) -> [DeclSyntax] {
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
            let res = transformInit(initializer)
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
            throw ComponentMacroErrorReport(errors: errors)
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

    private static func transformFunction(_ decl: FunctionDeclSyntax) -> Result<
        FunctionDeclSyntax?, ComponentMacroError
    > {
        let res = transformSignature(signature: decl.signature)
        guard
            case .success((let newSignature, let changed)) = res
        else {
            return .failure(res.error!)
        }

        if !changed {
            return .success(nil)
        }

        let callExpr: FunctionCallExprSyntax = FunctionCallExprSyntax(
            callee: ExprSyntax("\(decl.name)")
        ) {
            for p in decl.signature.parameterClause.parameters {
                LabeledExprSyntax(
                    label: p.firstName,
                    colon: p.colon,
                    expression: ExprSyntax("Bind(getter: \(p.secondName ?? p.firstName))")
                )
            }

        }

        // external name must be the same
        let out = FunctionDeclSyntax(
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

    private static func transformInit(_ decl: InitializerDeclSyntax) -> Result<
        InitializerDeclSyntax?, ComponentMacroError
    > {
        let res = transformSignature(signature: decl.signature)
        guard
            case .success((let newSignature, let changed)) = res
        else {
            return .failure(res.error!)
        }

        if !changed {
            return .success(nil)
        }

        let callExpr = FunctionCallExprSyntax(callee: ExprSyntax("self.init")) {
            for p in decl.signature.parameterClause.parameters {
                LabeledExprSyntax(
                    label: p.firstName,
                    colon: p.colon,
                    expression: ExprSyntax("Bind(getter: \(p.secondName ?? p.firstName))")
                )
            }

        }

        let out = InitializerDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: "convenience")
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

    private static func transformSignature(signature: FunctionSignatureSyntax)
        -> Result<(FunctionSignatureSyntax, changed: Bool), ComponentMacroError>
    {
        var parameters: [FunctionParameterSyntax] = []
        var shouldEmit = false
        for p in signature.parameterClause.parameters {
            // only if its bind
            guard let identifierType = p.type.as(IdentifierTypeSyntax.self),
                "\(identifierType.name)" == "Bind",
                let clause = identifierType.genericArgumentClause,
                let ty = clause.arguments.first
            else {
                parameters.append(p)
                continue
            }

            shouldEmit = true

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

        return .success((out, changed: shouldEmit))
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
