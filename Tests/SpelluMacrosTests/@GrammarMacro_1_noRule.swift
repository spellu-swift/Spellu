import SpelluMacros


@Test("@Grammarのマクロ展開")
func GrammarMacro_1_noRule() {
	expect(
		macros: [
			"Grammar": GrammarMacro.self,
			"Rule": RuleMacro.self,
		]
	) {
"""
@Grammar(
	spaces: [.space]
)
struct ExampleGrammar {
}
"""
	} expansion: {
"""
struct ExampleGrammar {
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
			]
		)
	}
}
"""
	}
}
