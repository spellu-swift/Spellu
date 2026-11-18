@testable import SpelluLex


// 対象API: TokenMatcher.init/stream/maxRepetition/match(TokenIR,onFailure:)。
// VMと同じ入力・上限で、成功位置、失敗時の巻き戻し、再利用、
// 部分範囲、設定の補正、独立した評価器での並行使用を確認する。
// 文法の意味論はTokenMatchingSemanticsTestsで両VMと同じ条件を使う。
@Suite struct TokenMatcherTests {

	@Test func 失敗した文字要素とその位置を巻き戻し前に通知する() {
		let input: TokenInputStream = .init("abcX")
		var matcher: TokenMatcher = .init(stream: input, maxRepetition: 65_535)
		var factors: [TokenIR.Factor] = []
		var starts: [Int] = []
		var offsets: [Int] = []
		let result: TokenMatchResult = matcher.match(.alternative([
			.string("abcd"), .string("ax"), .sequence([.string("abc"), .character(.include(.space))]),
		])) { factor, start, position in
			factors.append(factor)
			starts.append(input.offset(of: start))
			offsets.append(input.offset(of: position))
		}
		#expect(result == .failure(input.input.index(input.cursor, offsetBy: 3)))
		#expect(factors == [.string("abcd"), .string("ax"),
			.character(.include(.space))])
		#expect(offsets == [3, 1, 3])
		#expect(starts == [0, 0, 3])
		#expect(matcher.stream.cursor == input.cursor)
	}

	@Test func 部分入力の開始位置と終端を守る() {
		let source: TokenInputStream = .init("xΣb!", range: 1..<4)
		var matcher: TokenMatcher = .init(stream: source, maxRepetition: 65_535)
		#expect(matcher.stream.offset == 1)
		#expect(matcher.match(.string("Σb!")) == .failure(source.input.endIndex))
		#expect(matcher.stream.offset == 1)
		#expect(matcher.match(.string("σx").ignoresCase()).matchedEnd == nil)
		#expect(matcher.stream.offset == 1)
		let result: TokenMatchResult = matcher.match(.sequence([
			.string("σ").ignoresCase(),
			.string("b"),
		]))
		#expect(result == .success(source.input.endIndex))
		#expect(matcher.stream.offset == 4)
		#expect(matcher.match(.character(.include(.all)))
			== .failure(source.input.endIndex))
		#expect(matcher.stream.offset == 4)
		#expect(source.offset == 1)

		let bounded: TokenInputStream = .init("abc", range: 0..<1)
		for ignoresCase: Bool in [false, true] {
			var limited: TokenMatcher = .init(
				stream: bounded, maxRepetition: 65_535,
			)
			#expect(limited.match(
				.alternative([.string("ab"), .string("a")]).ignoresCase(ignoresCase),
			) == .success(bounded.input.endIndex))
			#expect(limited.stream.offset == 1)
		}
	}

	@Test func Matcherとパターンを再利用し上限を実行ごとに適用する() {
		let pattern: TokenIR = .string("a").repeat(1...)
		for limit: Int in [0, 1, 2, 3] {
			let stream: TokenInputStream = .init("aaa")
			var matcher: TokenMatcher = .init(
				stream: stream, maxRepetition: limit,
			)
			#expect((matcher.match(pattern).matchedEnd != nil) == (limit > 0))
			#expect(matcher.stream.offset == limit)
			#expect(stream.offset == 0)
		}

		var matcher: TokenMatcher = .init(
			stream: .init("aab"), maxRepetition: 65_535,
		)
		let choice: TokenIR = .alternative([.string("a"), .string("aa")])
		#expect(matcher.match(choice).matchedEnd != nil)
		#expect(matcher.stream.offset == 1)
		#expect(matcher.match(.string("missing")) == .failure(matcher.stream.cursor))
		#expect(matcher.stream.offset == 1)
		#expect(matcher.match(choice).matchedEnd != nil)
		#expect(matcher.stream.offset == 2)
		#expect(matcher.match(.string("b")).matchedEnd != nil)
		#expect(matcher.stream.offset == 3)
	}

	@Test func 最遠位置は照合ごとに初期化し成功時は採用した終了位置を返す() {
		let input: TokenInputStream = .init("abc!")
		let third: String.Index = input.input.index(
			input.cursor, offsetBy: 3,
		)
		let first: String.Index = input.input.index(after: input.cursor)
		var matcher: TokenMatcher = .init(stream: input, maxRepetition: 65_535)
		#expect(matcher.match(.string("abcX")) == .failure(third))
		#expect(matcher.match(.string("x")) == .failure(input.cursor))
		#expect(matcher.match(.alternative([.string("abcX"), .string("a")])) == .success(first))
		#expect(matcher.stream.cursor == first)
		#expect(matcher.match(.string("x")) == .failure(first))
		#expect(matcher.stream.cursor == first)
	}

	@Test(arguments: [
		(Int.min, 0), (-1, 0), (0, 0), (1, 1), (3, 3),
		(Int.max, Int.max - 1),
	])
	func 反復上限は入力から独立した評価器の設定として補正する(
		_ limit: Int,
		_ normalized: Int,
	) {
		let input: TokenInputStream = .init("aaa")
		var matcher: TokenMatcher = .init(stream: input, maxRepetition: limit)
		#expect(matcher.maxRepetition == normalized)
		let expected: Int? = normalized > 0 ? min(3, normalized) : nil
		let end: Int? = matcher.match(.string("a").repeat(1...)).matchedEnd.map {
			input.offset(of: $0)
		}
		#expect(end == expected)
		#expect(matcher.stream.offset == (expected ?? 0))

		var tooMany: TokenMatcher = .init(
			stream: input, maxRepetition: limit,
		)
		#expect(tooMany.match(.string("a").repeat(Int.max...Int.max))
			== .failure(input.cursor))
		#expect(tooMany.stream.offset == 0)
		#expect(input.offset == 0)
	}

	@Test func 入力の置き換えとコピーは他の評価器に影響しない() {
		let input: TokenInputStream = .init("aab")
		var original: TokenMatcher = .init(stream: input, maxRepetition: 2)
		#expect(original.match(.string("a")).matchedEnd != nil)
		var copy: TokenMatcher = original
		#expect(copy.match(.string("ab")).matchedEnd != nil)
		#expect(copy.stream.offset == 3)
		#expect(original.stream.offset == 1)

		original.stream = .init("xΣb!", range: 1..<4)
		#expect(original.maxRepetition == 2)
		#expect(original.match(.string("Σb"))
			== .success(original.stream.input.endIndex))
		#expect(original.stream.offset == 4)
		#expect(copy.stream.offset == 3)
		#expect(input.offset == 0)
	}

	@Test func 同じパターンを独立したMatcherから並行して使用できる() async {
		let pattern: TokenIR = .sequence([.alternative([.string("aa"), .string("a")]), .string("b")])
		let cases: [(String, Int?)] = [
			("aab", 3), ("ab", 2), ("aa", nil), ("b", nil),
		]
		await withTaskGroup(of: Bool.self) { group in
			for (input, expected) in cases {
				group.addTask {
					var matcher: TokenMatcher = .init(
						stream: .init(input), maxRepetition: 65_535,
					)
					let actual: Int? = matcher.match(pattern).matchedEnd.map {
						matcher.stream.offset(of: $0)
					}
					return actual == expected
						&& matcher.stream.offset == (expected ?? 0)
				}
			}
			for await matched: Bool in group { #expect(matched) }
		}
	}

}
