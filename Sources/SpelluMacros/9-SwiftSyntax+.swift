import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftBasicFormat


extension String {
	
	func trimmed(
		suffix string: String,
	) -> String {
		if hasSuffix(string) {
			return String(self.dropLast(string.count))
		}
		else {
			return self
		}
	}
	
}


extension DeclGroupSyntax {
	
	var variables: [VariableDeclSyntax] {
		memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
	}
	
}


/// public, internal, private, fileprivate, static
extension DeclModifierListSyntax {
	
	func contains(
		token: TokenKind,
	) -> Bool {
		self.contains{ $0.name.tokenKind == token }
	}
	
	mutating func remove(
		token: TokenKind,
	) {
		if
			let index = self.firstIndex(where: { $0.name.tokenKind == token })
		{
			self.remove(
				at: index
			)
		}
	}
	
	var names: [String] {
		self.map {
			$0.name.text
		}
	}

}


extension VariableDeclSyntax {
	
	var identifier: String? {
		bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
	}
	
	var type: String? {
		bindings.first?.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text
	}
	
}


extension AttributeListSyntax {
	
	var names: [String] {
		self.compactMap {
			$0.attributeNameText
		}
	}
	
	func attribute(
		name: String,
	) -> AttributeSyntax? {
		first {
			$0.attributeNameText == name
		}?.as(AttributeSyntax.self)
	}
	
}


extension AttributeListSyntax.Element {
	
	var attributeNameText: String? {
		self.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text
	}
	
}


/// @XXX の引数
extension AttributeSyntax {
	
	func arguement(
		label: String,
	) -> ExprSyntax? {
		if
			case .argumentList(let labeledExpr) = self.arguments,
			let expr: ExprSyntax = labeledExpr.first(label: label)
		{
			return expr
		}
		
		return nil
	}
	
	func value(
		label: String,
		default value: String,
	) -> String {
		if
			let syntax: ExprSyntax = self.arguement(label: "behavior")
		{
			syntax.trimmedDescription
		} else {
			value
		}
	}
	
}


extension LabeledExprListSyntax {

	func first(
		label: String,
	) -> ExprSyntax? {
		self.first {
			$0.label?.text == label
		}?.expression
	}
	
}


extension SyntaxStringInterpolation {

	public mutating func appendInterpolation(
		spacePattern buildable: (some SyntaxProtocol)?,
		format: BasicFormat = BasicFormat(),
	) {
		if
			let buildable
		{
			self.appendInterpolation(buildable.formatted(using: format))
		}
		else {
			self.appendInterpolation(raw: ".none")
		}
	}
	
}
