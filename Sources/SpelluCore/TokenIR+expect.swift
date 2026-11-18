import SpelluLex


extension TokenIR {

	/// 入力を探索し、指定された最遠失敗位置の文字・リテラルだけを返す。
	package func expectations(
		in stream: SourceStream,
		at position: String.Index,
	) -> [Expect] {
		var result: [Expect] = []
		var matcher: TokenMatcher = .init(
			stream: .init(
				input: stream.source.asSubstring, cursor: stream.cursor,
			),
			maxRepetition: stream.maxTokenRepetition,
		)

		_ = matcher.match(self) { factor, start, failedAt in
			guard
				failedAt == position
			else { return }

			let expect: Expect
			switch factor {
				case let .character(set):
					expect = set.expect

				case let .string(string):
					// 大小文字無視では原文とリテラルのUTF-8長が異なり得る。
					let count: Int = stream.input.unicodeScalars.distance(
						from: start, to: failedAt,
					)
					expect = .literal(String(string.unicodeScalars.dropFirst(count)))

				case .alternative, .sequence: return
			}
			if !result.contains(expect) { result.append(expect) }
		}
		return result
	}

	/// 入力を伴わない診断に使う、重複のない文字・リテラルの一覧。
	package var expects: [Expect] {
		if
			let expect
		{
			return [.special(expect)]
		}

		let values: [Expect]
		switch factor {
			case let .character(set): values = [set.expect]
			case let .string(string): values = [.literal(string)]	// TODO
			case let .alternative(rules), let .sequence(rules):
				values = rules.flatMap(\.expects)
		}

		return values.reduce(into: []) { result, expect in
			if !result.contains(expect) {
				result.append(expect)
			}
		}
	}

}


extension CharacterSet {
	
	package var expect: Expect {
		guard
			categories.isNotEmpty
		else { return inverted ? .character("ALL") : .character("EMPTY") }

		let body: String
		= categories.map(\.expectString).joined(separator: " | ")

		return inverted ? .character("not(\(body))") : .character(body)
	}
	
}


extension CharacterPattern {

	@inlinable
	package var expect: Expect {
		.character(expectString)
	}

	// TODO: 仕様決め
	@inlinable
	package var expectString: String {
		switch self {
			case .binary, .general:
				"\(self)"
			default:
				"\(self)".uppercased()
		}
	}

}

