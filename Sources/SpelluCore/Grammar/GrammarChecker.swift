import SpelluLex


extension GrammarChecker {
	
	public static func check(
		_ grammar: SpelluGrammar,
	) throws(SpelluError) {
		var checker: Self = .init(grammar: grammar)
		try checker.check()
	}

}


/// 文法が満たす必要のある条件を検証する。
public struct GrammarChecker {

	let grammar: SpelluGrammar
	var nullableRules: Set<String> = []

	private init(grammar: SpelluGrammar) {
		self.grammar = grammar
	}

	private mutating func check() throws(SpelluError) {
		guard
			grammar.rules.contains(where: \.expose)
		else { throw .noExposedRule(grammar: grammar.name) }

		for rule: SpelluRule in grammar.rules {
			try checkSyntax(
				rule.syntax.ir,
				rule: rule.name,
			)
		}

		for space: SpacePattern in grammar.spaces {
			if case let .token(pattern) = space {
				try checkToken(pattern, rule: "#trivia")
			}
		}
	}

	private func checkSyntax(
		_ syntax: [SyntaxIR],
		rule: String,
	) throws(SpelluError) {
		for ir: SyntaxIR in syntax {
			switch ir {
				case .trivia:
					guard
						grammar.hasTrivia
					else {
						throw .emptyMatch(rule: "Trivia")
					}

				case
					let .token(_, pattern, _, _),
					let .word(_, pattern, _, _)
					:
					try checkToken(pattern, rule: rule)

				case let .sequence(_, body), let .atomic(body), let .choiceOf(body), let .optional(body), let .capture(body):
					try checkSyntax(body, rule: rule)
					
				case let .anyOf(branches):
					for branch in branches {
						try checkPrecedence(
							branch.precedence.rawValue,rule: rule,
						)
						try checkSyntax(branch.body, rule: rule)
					}

				case let .repeat(body, amount, _):
					try checkAmount(amount, rule: rule)
					try checkSyntax(body, rule: rule)

				case let .list(value, separator, _, amount):
					try checkAmount(amount, rule: rule)
					try checkSyntax(value, rule: rule)
					try checkSyntax(separator, rule: rule)

				case let .enclosure(body, amount, _, opener, closer):
					try checkAmount(amount, rule: rule)
					try checkSyntax(body, rule: rule)
					try checkSyntax(opener, rule: rule)
					try checkSyntax(closer, rule: rule)

				case let .relabel(_, body):
					try checkRelabel(body, rule: rule)

				case .ruleref, .tokenref:
					break
			}
		}
	}

}


extension GrammarChecker {

	/// 字句の数量は、SequenceやChoiceOfの子についても検証する。
	func checkToken(
		_ pattern: TokenIR,
		rule: String,
	) throws(SpelluError) {
		try checkAmount(pattern.amount, rule: rule)

		switch pattern.factor {
			case let .sequence(patterns), let .alternative(patterns):
				for child: TokenIR in patterns {
					try checkToken(child, rule: rule)
				}
			case .string, .character: break
		}
	}

	func checkRelabel(
		_ body: SyntaxIR,
		rule: String,
	) throws(SpelluError) {
//		switch body {
//			case .choiceOf(<#T##[SyntaxIR]#>)
//		}
	}

	func checkAmount(
		_ amount: Amount,
		rule: String,
	) throws(SpelluError) {
		guard amount.min >= 0,
			amount.max.map({ $0 >= amount.min }) ?? true
		else {
			throw .invalidAmount(
				grammar: grammar.name,
				rule: rule,
				amount: amount,
			)
		}
	}

	/// 列挙型の表現とは独立に、precedenceの整数値を検証する。
	func checkPrecedence(
		_ precedence: Int,
		rule: String,
	) throws(SpelluError) {
		guard
			Precedence.min.rawValue <= precedence,
			precedence <= Precedence.max.rawValue
		else {
			throw .precedenceOutOfRange(
				grammar: grammar.name,
				rule: rule,
				precedence: precedence,
			)
		}
	}

}
