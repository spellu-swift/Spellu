import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics


public struct GrammarMacro {}


// MARK: Grammarマクロの実装

extension GrammarMacro : ExtensionMacro {
	
	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext,
	) throws -> [ExtensionDeclSyntax] {
		let typeName: String
		let grammarName: String
		let spaces: String

		typeName = "\(type.trimmed)"
		
		grammarName = typeName.trimmed(suffix: "Grammar")
		
		if
			let syntax: ExprSyntax
				= node.arguement(label: "spaces")
		{
			spaces = syntax.trimmedDescription
		} else {
			spaces = "[.space, .newline]"
		}
		
		let ruleCodes: [VariableDeclSyntax]
		= declaration.variables
			.filter{ $0.attributes.names.contains("Rule") == true }
			.filter{ $0.modifiers.names.contains("private") == false && $0.modifiers.names.contains("fileprivate") == false }
			.filter{ $0.modifiers.names.contains("static") == false }

		let ruleAttributes: [(
			name: String,
			label: String,
			expose: Bool,
		)]
		= ruleCodes.map {
			(
				name: $0.identifier!,
				label: $0.attributes.attribute(name: "Rule")?.arguement(label: "label")?.trimmedDescription ?? ".none",
				expose: $0.modifiers.names.contains("public"),
			)
		}

		let triviaRules: [String] = ruleCodes.compactMap { rule in
			guard let condition = rule.attributes.attribute(name: "Rule")?
				.arguement(label: "trivia")
			else { return nil }
			let name: String = rule.identifier!
			return "(\(condition.trimmedDescription) ? "
				+ "[\"\(name)\"] : [])"
		}

		let trivia: String
		= triviaRules.isEmpty ? "[]" : triviaRules.joined(separator: " + ")

		let extraExtension = try ExtensionDeclSyntax("""
extension \(raw: typeName) : GrammarDeclaration {
	public static let `default`: \(raw: typeName) = .init()

	public static let id: String = "\(raw: grammarName)"

	public func grammar() -> SpelluGrammar {
		.init(
			name: "\(raw: grammarName)",
			spaces: \(raw: spaces),
			trivia: \(raw: trivia),
			rules: [\(raw: ruleAttributes.map{"\n\t\t\t\t(name: \"\($0.name)\", label: \($0.label), expose: \($0.expose), syntax: self.\($0.name)),"}.joined())
			]
		)
	}
}
""")

		return [extraExtension]
	}
	
}
