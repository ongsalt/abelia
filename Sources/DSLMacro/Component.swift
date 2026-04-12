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
    ) throws(ComponentMacroError) -> [DeclSyntax] {
        let (functions, initializers) = findFunctionsAndInit(declaration)

        return functions.compactMap { fn in DeclSyntax(transformFunction(fn)) }
            + initializers.compactMap { initializer in DeclSyntax(transformInit(initializer)) }
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

    private static func transformFunction(_ decl: FunctionDeclSyntax) -> FunctionDeclSyntax? {
        let (newSignature, changed) = transformSignature(signature: decl.signature)
        if !changed {
            return nil
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
            signature: newSignature,
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

        return out
    }

    private static func transformInit(_ decl: InitializerDeclSyntax) -> InitializerDeclSyntax? {
        let (newSignature, changed) = transformSignature(signature: decl.signature)
        if !changed {
            return nil
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
            signature: newSignature,

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

        return out
    }

    private static func transformSignature(signature: FunctionSignatureSyntax) -> (
        FunctionSignatureSyntax, changed: Bool
    ) {
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

        return (out, changed: shouldEmit)
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
