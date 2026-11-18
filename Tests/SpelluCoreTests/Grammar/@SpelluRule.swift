import SpelluCore


@Suite struct SpelluRuleTests {

	@Test func ルールは既定で文法外部に非公開() {
		let rule: SpelluRule
		= .init(name: "value", syntax: Syntax { Token("a") })

		#expect(rule.name == "value")
		#expect(rule.label == .none)
		#expect(rule.expose == false)
		#expect(rule.syntax.ir.count == 1)
	}

	@Test(arguments: [false, true])
	func 文法への登録でルールの属性を保持(expose: Bool) throws {
		let grammar: SpelluGrammar
		= .init(
			name: "Example",
			spaces: [],
			trivia: [],
			rules: [(
				name: "value",
				label: "valueLabel",
				expose: expose,
				syntax: Syntax { Token("a") },
			)],
		)

		let rule: SpelluRule = try #require(grammar.rule(for: "value"))
		#expect(rule.name == "value")
		#expect(rule.label == "valueLabel")
		#expect(rule.expose == expose)
		#expect(rule.syntax.ir.count == 1)
	}

	@Test func 初期化時に非公開のルールを登録する() {
		let grammar: SpelluGrammar
		= .init(name: "Example", spaces: [], trivia: [], rules: [
			(name: "value", label: .none, expose: false,
				syntax: Syntax { Token("a") }),
		])

		#expect(grammar.rules[0].expose == false)
		#expect(grammar.rule(for: "value")?.name == grammar.rules[0].name)
	}

	@Test(arguments: [false, true])
	func 初期化時にルールの公開可否を指定(expose: Bool) {
		let grammar: SpelluGrammar
		= .init(name: "Example", spaces: [], trivia: [], rules: [
			(name: "value", label: .none, expose: expose,
				syntax: Syntax { Token("a") }),
		])

		#expect(grammar.rules[0].expose == expose)
		#expect(grammar.rule(for: "value")?.name == grammar.rules[0].name)
	}
}


@Grammar(spaces: [])
private struct ExposeTestGrammar {
	@Rule public let externalRule = Syntax { Token("a") }
	@Rule let defaultRule = Syntax { Token("b") }
	@Rule internal let internalRule = Syntax { Token("c") }
}


@Test func publicなRuleだけが文法外部に公開される() throws {
	let grammar: SpelluGrammar = ExposeTestGrammar.default.grammar()

	#expect(grammar.rules.count == 3)
	#expect(try #require(grammar.rule(for: "externalRule")).expose == true)
	#expect(try #require(grammar.rule(for: "defaultRule")).expose == false)
	#expect(try #require(grammar.rule(for: "internalRule")).expose == false)
}
