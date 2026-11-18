import SpelluCore


extension Spellu {

	func resolve(
		_ reference: RuleReference?,
	) throws -> RuleReference {
		// 文法が1つ以上必要
		guard
			let first: SpelluGrammar = grammars.first
		else { throw SpelluError.grammarNotFound(grammar: reference?.grammar ?? "") }

		let grammarName: String
		= reference?.grammar ?? first.name

		let ruleName: String
		if let reference {
			ruleName = reference.rule
		}
		else {
			guard
				let rule: SpelluRule
					= first.rules.first(where: \.expose)
			else { throw SpelluError.noExposedRule(grammar: first.name) }

			ruleName = rule.name
		}

		guard
			let grammar = grammars.first(where: { $0.name == grammarName })
		else { throw SpelluError.grammarNotFound(grammar: grammarName) }

		guard
			grammar.rule(for: ruleName) != nil
		else {
			throw SpelluError.ruleNotFound(grammar: grammarName, rule: ruleName)
		}

		return .init(grammar: grammarName, rule: ruleName)
	}

}
