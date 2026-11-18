import SpelluCore
import SpelluLex


extension ModelBuilder {

	/// モデル生成も構文の深さをSwiftの呼び出し深さへ変換しない。
	func validate(
		_ grammar: SpelluGrammar,
	) throws {
		guard
			grammar.rules.contains(where: \.expose)
		else { throw SpelluError.noExposedRule(grammar: grammar.name) }

		var pending: [(SyntaxIR, String)]
		= grammar.rules.flatMap { rule in
			rule.syntax.ir.map { ($0, rule.name) }
		}

		for space: SpacePattern in grammar.spaces {
			switch space {
				case .token(let value):
					try validateToken(value, grammar.name, "#trivia")
				default:
					break
			}
		}

		for rule: String in grammar.trivia {
			pending.append((.ruleref(nil, rule), "#trivia"))
		}

		while let (ir, rule): (SyntaxIR, String) = pending.popLast() {
			var children: [SyntaxIR] = []

			switch ir {
				case .token(_, let pattern, _, _),
					.word(_, let pattern, _, _):
					try validateToken(pattern, grammar.name, rule)
				case .sequence(_, let body),
					.choiceOf(let body),
					.optional(let body),
					.atomic(let body),
					.capture(let body):
					children = body
				case .anyOf(let branches):
					for branch: Branch in branches {
						let rank: Int
						= branch.precedence.rawValue

						guard
							Precedence.min.rawValue...Precedence.max.rawValue
								~= rank
						else {
							throw SpelluError.precedenceOutOfRange(
								grammar: grammar.name,
								rule: rule,
								precedence: rank,
							)
						}

						children += branch.body
					}
				case .repeat(let body, let amount, _):
					try validateAmount(amount, grammar.name, rule)
					children = body
				case .list(let body, let separator, _, let amount):
					try validateAmount(amount, grammar.name, rule)
					children = body + separator
				case .enclosure(let body, let amount, _, let opener, let closer):
					try validateAmount(amount, grammar.name, rule)
					children = body + opener + closer
				case .relabel(_, let value):
					children = [value]
				case .trivia:
					if !grammar.hasTrivia {
						throw SpelluError.emptyMatch(rule: "Trivia")
					}
				default:
					break
			}

			pending.append(contentsOf: children.map { ($0, rule) })
		}
	}

	private func validateToken(
		_ pattern: TokenIR,
		_ grammar: String,
		_ rule: String,
	) throws {
		var pending: [TokenIR]
		= [pattern]

		while let value: TokenIR = pending.popLast() {
			try validateAmount(value.amount, grammar, rule)

			switch value.factor {
				case .sequence(let children), .alternative(let children):
					pending.append(contentsOf: children)
				default:
					break
			}
		}
	}

	private func validateAmount(
		_ amount: Amount,
		_ grammar: String,
		_ rule: String,
	) throws {
		guard
			amount.min >= 0,
			amount.max.map({ $0 >= amount.min }) ?? true
		else {
			throw SpelluError.invalidAmount(
				grammar: grammar,
				rule: rule,
				amount: amount,
			)
		}
	}

}
