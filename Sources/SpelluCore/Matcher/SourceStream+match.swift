import SpelluLex


extension SourceStream {

	/// 空白パターンのマッチ
	mutating func match(
		_ trivia: [SpacePattern],
	) -> TokenMatchResult {
		let pattern: TokenIR
		= .alternative(
			trivia.map {
				switch $0 {
				case .space:
						.character(.include(.space))
				case .newline:
						.character(.include(.newline))
				case .character(let `class`):
						.character(`class`.set)
				case .string(let string):
						.string(string)
				case .token(var pattern):
					{
						if pattern.amount.min == 0 {
							pattern.amount
							= switch pattern.amount {
							case .zeroOrMore:
									.oneOrMore
							case .oneOrMore:
									.oneOrMore
							case .zeroOrOne:
									.exactly(1)
							case .exactly:
									.exactly(1)
							case .nOrMore:
									.nOrMore(1)
							case .upToN:
									.exactly(1)
							case .range(_, let m):
									.range(1, m)
							}
						}
						return pattern
					}()
				}
			},
			amount: .oneOrMore,
		)

		return match(pattern)
	}
	
	/// 文字列のマッチ
	@inlinable
	mutating func match(
		_ string: String,
		caseInsensitive: Bool? = nil,
	) -> TokenMatchResult {
		return match(.string(string, caseInsensitive: caseInsensitive))
	}
	
}


extension SourceStream {
	
	/// 入力位置を変えず、一致終了位置または最遠失敗位置を返す。
	public func match(
		_ pattern: TokenIR,
	) -> TokenMatchResult {
		let tokenInput: TokenInputStream
		= .init(input: source.asSubstring, cursor: cursor)
		
		return tokenInput.match(
			pattern,
			engine: engine,
			maxTokenRepetition: maxTokenRepetition,
		)
	}
	
	/// 入力位置を変えず、一致終了位置または最遠失敗位置を返す。
	public func match(
		_ pattern: TokenProgram,
	) -> TokenMatchResult {
		guard
			engine == .momojiri
		else { return .failure(cursor) }

		let tokenInput: TokenInputStream
		= .init(input: source.asSubstring, cursor: cursor)
		
		return tokenInput.match(
			pattern,
			maxTokenRepetition: maxTokenRepetition,
		)
	}
	
}


