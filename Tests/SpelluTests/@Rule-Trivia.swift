import Spellu


@Grammar(spaces: [.space])
private struct RuleTriviaGrammar {
	@Rule public let root = Syntax { Token("a"); Token("b") }
	@Rule(trivia: true) let comment = Syntax { Fragment("#") }
	@Rule(trivia: false) let ordinary = Syntax { Fragment("!") }

	@Rule public let nested = Syntax {
		Token("a")
		Rule("NestedTrivia", "root")
		Token("b")
	}
}


@Grammar(spaces: [.newline])
private struct NestedTriviaGrammar {
	@Rule public let root = Syntax { Token("x") }
	@Rule(trivia: true) let comment = Syntax { Fragment("@") }
}


@Suite struct RuleTriviaTests {
	private static let engines: [Spellu.Engine]
	= [.interpreter, .sakuya, .hoori]

	@Test(arguments: engines)
	func Ruleで指定したTriviaと既存の字句Triviaを使う(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(
			RuleTriviaGrammar.default,
			NestedTriviaGrammar.default,
		)
		#expect(try parser.parse("a # b").string == "a # b")
		#expect(throws: SpelluError.self) { try parser.parse("a ! b") }
	}

	@Test(arguments: engines)
	func 別文法から戻ると本文と末尾で呼び出し元のTriviaを読む(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(
			RuleTriviaGrammar.default,
			NestedTriviaGrammar.default,
		)
		let rule: RuleReference = .init(grammar: "RuleTrivia", rule: "nested")
		let tree: SourceTree = try parser.parse(
			" # a\n@x # b # ",
			method: .whole,
			as: rule,
		)

		#expect(tree.root.string == "a\n@x # b")
	}

	@Test func Grammarに追加される参照を確認する() {
		let grammar: SpelluGrammar = RuleTriviaGrammar.default.grammar()
		#expect(grammar.spaces.count == 1)
		#expect(grammar.trivia == ["comment"])
	}
}
