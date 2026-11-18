

public struct RuleReference : Sendable {
	
	public init(
		grammar: String?,
		rule: String,
	) {
		self.grammar = grammar
		self.rule = rule
	}
	
	public let grammar: String?
	public let rule: String
	
}


extension RuleReference : ExpressibleByStringLiteral {
	
	@inlinable
	public init(
		stringLiteral value: StringLiteralType,
	) {
		self.grammar = nil
		self.rule = value
	}

}

extension RuleReference {

	@inlinable
	public static func grammar(
		_ name: String?,
		rule: String,
	) -> Self {
		.init(grammar: name, rule: rule)
	}
	
	@inlinable
	public static func rule(
		_ name: String,
	) -> Self {
		.init(grammar: nil, rule: name)
	}
	
}


extension RuleReference {
	
	@inlinable
	public var ir: SyntaxIR {
		.ruleref(grammar, rule)
	}

	@inlinable
	public func optional(
	) -> SyntaxIR {
		.optional([ir])
	}
	
	public func `as`(
		label: String
	) -> SyntaxIR {
		.relabel(label: label, ir)
	}
	
	public func precedence(
		_ precedence: Precedence,
	) -> Branch {
		.init(precedence: precedence, body: [ir])
	}

}
