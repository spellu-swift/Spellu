import Basis


public struct Branch : Hashable, Sendable {
	
	public init(
		_ precedence: Precedence,
		@SyntaxBuilder _ body: () -> [SyntaxIR],
	) {
		self.precedence = precedence
		self.body = body()
	}
	
	init(
		precedence: Precedence,
		body: [SyntaxIR],
	) {
		self.precedence = precedence
		self.body = body
	}
	
	public let precedence: Precedence
	public let body: [SyntaxIR]

}


/// 成功した候補を優先値で選ぶ構文選択。
@inlinable
public func AnyOf(
	@AnyOfBuilder _ body: () -> [Branch],
) -> SyntaxIR {
	.anyOf(body())
}


/// AnyOfの各候補を、優先値付きのBranchとして組み立てる。
@resultBuilder
public class AnyOfBuilder {

	public static func buildExpression(
		_ syntax: SyntaxIR,
	) -> Branch {
		.init(precedence: .default, body: [syntax])
	}

	public static func buildExpression(
		_ syntax: [SyntaxIR],
	) -> Branch {
		.init(precedence: .default, body: syntax)
	}

	public static func buildExpression(
		_ ref: RuleReference,
	) -> Branch {
		.init(
			precedence: .default,
			body: [
				.ruleref(ref.grammar, ref.rule),
			],
		)
	}

	// ex) "spellu"
	public static func buildExpression(
		_ string: String,
	) -> Branch {
		.init(
			precedence: .default,
			body: [
				.token(
					.none,
					[.string(string)],
					spacious: true,
				),
			],
		)
	}

	public static func buildExpression(
		_ branch: Branch,
	) -> Branch {
		branch
	}

	public static func buildExpression(
		_ branches: [Branch],
	) -> [Branch] {
		branches
	}

	public static func buildBlock(
	) -> [Branch] {
		[]
	}

	public static func buildPartialBlock(
		first: Branch,
	) -> [Branch] {
		[first]
	}

	public static func buildPartialBlock(
		first: [Branch],
	) -> [Branch] {
		first
	}

	public static func buildPartialBlock(
		accumulated: [Branch],
		next: Branch,
	) -> [Branch] {
		accumulated + [next]
	}

	public static func buildPartialBlock(
		accumulated: [Branch],
		next: [Branch],
	) -> [Branch] {
		accumulated + next
	}

}



