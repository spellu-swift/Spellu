import SpelluMacros

@Test("@Ruleのtrivia指定を@Grammarへ追加する")
func GrammarMacro_ルールをTriviaに追加する() {
	expect(macros: ["Grammar": GrammarMacro.self]) {
"""
@Grammar(spaces: [.space])
struct ExampleGrammar {
    @Rule(trivia: true) var comment = Syntax {}
    @Rule(trivia: false) var other = Syntax {}
}
"""
	} expansion: {
"""
struct ExampleGrammar {
    @Rule(trivia: true) var comment = Syntax {}
    @Rule(trivia: false) var other = Syntax {}
}

extension ExampleGrammar : GrammarDeclaration {
	public static let `default`: ExampleGrammar = .init()

	public static let id: String = "Example"

	public func grammar() -> SpelluGrammar {
		.init(
			name: "Example",
			spaces: [.space],
			trivia: (true ? ["comment"] : []) + (false ? ["other"] : []),
			rules: [
				(name: "comment", label: .none, expose: false, syntax: self.comment),
				(name: "other", label: .none, expose: false, syntax: self.other),
			]
		)
	}
}
"""
	}
}
