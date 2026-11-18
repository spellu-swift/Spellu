import SpelluLex


/// Swift.Stringの正規等価性と、字句が読むScalar列の同一性を分ける。
struct PatternKey : Hashable {

	private enum Part : Hashable {
		case settings(Amount, TokenRepetitionBehavior, Bool?, [UInt8]?)
		case literal([UInt8])
		case character(CharacterSet)
		case sequence(Int)
		case alternative(Int)
	}

	private let parts: [Part]

	init(
		_ pattern: TokenIR,
	) {
		var pending: [TokenIR]
		= [pattern]

		var result: [Part]
		= []

		while let value: TokenIR = pending.popLast() {
			result.append(
				.settings(
					value.amount,
					value.behavior,
					value.caseInsensitive,
					value.expect.map { Array($0.utf8) },
				),
			)

			switch value.factor {
				case .string(let text):
					result.append(.literal(Array(text.utf8)))
				case .character(let set):
					result.append(.character(set))
				case .sequence(let children):
					result.append(.sequence(children.count))
					pending.append(contentsOf: children.reversed())
				case .alternative(let children):
					result.append(.alternative(children.count))
					pending.append(contentsOf: children.reversed())
			}
		}

		parts = result
	}

}
