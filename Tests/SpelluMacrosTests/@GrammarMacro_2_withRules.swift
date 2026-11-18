import SpelluMacros
import SwiftSyntax
import SwiftParser


@Test("@Grammarと@Ruleのマクロ展開")
func GrammarMacro_2_withRules() {
	expect(
		macros: [
			"Grammar": GrammarMacro.self,
			"Rule": RuleMacro.self,
		],
		indentationWidth: .tabs(1)
	) {
"""
@Grammar(
	spaces: [.space]
)
struct ExampleGrammar {
	@Rule
	public let foo = Syntax {
	}

	@Rule
	var bar = Syntax {
	}

	var hoge = 0
}
"""
	} expansion: {
"""
struct ExampleGrammar {
	public let foo = Syntax {
	}

	public var $foo: RuleReference {
		Self.$foo
	}

	public static let $foo: RuleReference = .init(grammar: id, rule: "foo")
	var bar = Syntax {
	}

	var $bar: RuleReference {
		Self.$bar
	}

	static let $bar: RuleReference = .init(grammar: id, rule: "bar")

	var hoge = 0
}

extension ExampleGrammar : GrammarDeclaration {
	public static let `default`: ExampleGrammar = .init()

	public static let id: String = "Example"

	public func grammar() -> SpelluGrammar {
		.init(
			name: "Example",
			spaces: [.space],
			trivia: [],
			rules: [
				(name: "foo", label: .none, expose: true, syntax: self.foo),
				(name: "bar", label: .none, expose: false, syntax: self.bar),
			]
		)
	}
}
"""
	}
}

