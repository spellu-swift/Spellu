import SwiftCompilerPlugin
import SwiftSyntaxMacros



@main
struct SpelluPlugin : CompilerPlugin {

	let providingMacros: [Macro.Type] = [
		GrammarMacro.self,
		RuleMacro.self,
	]

}
