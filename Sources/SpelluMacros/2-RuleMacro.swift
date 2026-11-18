import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics


public struct RuleMacro {}


// MARK: Ruleマクロの実装

extension RuleMacro : PeerMacro {
	
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext,
	) throws -> [DeclSyntax] {
		// CHECK: 変数であること
		guard
			let varDecl = declaration.as(VariableDeclSyntax.self),
			let varName = varDecl.identifier
		else {
			throw DiagnosticsError(
				diagnostics: [
					Diagnostic(
						node: declaration,
						message: RuleMacroError.mustVariable,
					),
				]
			)
		}
		
		// CHECK: staticが付いていないこと
		guard
			varDecl.modifiers.contains(token: .keyword(.static)) == false
		else {
			var newVarDecl = varDecl

			// FIXME: staticに付随するtriviaが削除されているようだ。
			newVarDecl.modifiers.remove(token: .keyword(.static))

			throw DiagnosticsError(
				diagnostics: [
					Diagnostic(
						node: varDecl,
						message: RuleMacroError.useStaticKeyword,
						fixIt: .replace(
							message: RuleMacroFixIt.removeStaticKeyword,
							oldNode: varDecl,
							newNode: newVarDecl,
						),
					),

				]
			)
		}
		
		let accessibleToken: String = {
			if varDecl.modifiers.contains(token: .keyword(.public)) {
				"public "
			}
			else if varDecl.modifiers.contains(token: .keyword(.private)) {
				"private "
			}
			else if varDecl.modifiers.contains(token: .keyword(.fileprivate)) {
				"fileprivate "
			}
			else {
				""
			}
		}()

		let instanceDecl: DeclSyntax = """
\(raw: accessibleToken)var $\(raw: varName): RuleReference {
	Self.$\(raw: varName)
}
"""

		let staticDecl: DeclSyntax = """
\(raw: accessibleToken)static let $\(raw: varName): RuleReference = .init(grammar: id, rule: "\(raw: varName)")
"""

		return [
			instanceDecl,
			staticDecl,
		]
	}
	
}


public enum RuleMacroError : String, Swift.Error {
	
	case mustVariable = "must let/var"
	case useStaticKeyword = "cannot use `static` keyword"
	
}


extension RuleMacroError : DiagnosticMessage {
	
	public var message: String { self.rawValue }

	public var diagnosticID: MessageID {
		MessageID(domain: "Spellu", id: "\(type(of: self)).\(self)")
	}

	public var severity: DiagnosticSeverity { .error }

}


public enum RuleMacroFixIt : String {
	
	case removeStaticKeyword = "remove `static`"
	
}


extension RuleMacroFixIt : FixItMessage {
	
	public var message: String { self.rawValue }
	
	public var fixItID: MessageID {
		MessageID(domain: "Spellu", id: "\(type(of: self)).\(self)")
	}	
	
}
