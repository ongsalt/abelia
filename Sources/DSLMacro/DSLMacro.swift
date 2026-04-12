import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@main
struct DSLMacroPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        AutobindMacro.self,
    ]
}
