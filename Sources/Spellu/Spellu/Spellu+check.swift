import SpelluCore


extension Spellu {
	
	static func check(
		_ grammars: [SpelluGrammar],
	) throws {
		var names: Set<String> = []

		for grammar: SpelluGrammar in grammars {
			guard
				names.insert(grammar.name).inserted
			else {
				throw SpelluError.duplicateGrammar(grammar: grammar.name)
			}

			var rules: Set<String> = []

			for rule: SpelluRule in grammar.rules {
				guard rules.insert(rule.name).inserted else {
					throw SpelluError.duplicateRule(
						grammar: grammar.name, rule: rule.name,
					)
				}
			}

			try GrammarChecker.check(grammar)
		}
	}

	func checkStart(
		_ offset: Int,
		source: Source,
	) throws {
		guard
			source.range.lowerBound <= offset,
			offset <= source.range.upperBound,
			0 <= offset, offset <= source.content.utf8.count
		else { throw SpelluError.invalidStartOffset(offset) }

		let index: String.Index
		= source.content.utf8.index(
			source.content.utf8.startIndex, offsetBy: offset,
		)

		guard
			index.samePosition(in: source.content.unicodeScalars) != nil
		else { throw SpelluError.invalidStartOffset(offset) }
	}

}
