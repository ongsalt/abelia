import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct StateMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {

        guard case .argumentList(let list) = node.arguments,
            case .stringLiteralExpr(let s) = list.first?.expression.as(ExprSyntaxEnum.self)
        else {
            // throw .invalidArguments
            return []
        }

        let rawText = s.segments.map {
            switch $0 {
            case .stringSegment(let segment): segment.content.text
            case .expressionSegment: ""  // this should throw mf
            }
        }
        .joined()

        let sa: DeclSyntax = """
            let sa\(raw: rawText.count) = \"""
            \(raw: rawText)
            \"""
            let \(raw: node.attributeName) = 1276372
            let \(raw: context.makeUniqueName("hihi")) = 1002
            """

        return [sa]
    }
}
