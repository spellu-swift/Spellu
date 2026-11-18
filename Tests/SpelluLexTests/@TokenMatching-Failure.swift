@testable import SpelluLex


// 共通条件: 不一致のScalarの直前、EOF、選択・反復の巻き戻し、部分入力。
// Matcher、汎用VM、最適化VMで最遠位置と開始位置への復元を確認する。
@Suite struct TokenMatchingFailureTests {

	@Test(arguments: TokenMatchingEngine.allCases)
	func 文字列の部分一致と入力終端の失敗位置を返す(
		engine: TokenMatchingEngine,
	) {
		check(.string("abc"), "abX", failure: 2, engine: engine)
		check(.string("abcd"), "ab", failure: 2, engine: engine)
		check(.string("a"), "b", failure: 0, engine: engine)
		check(.string("a"), "", failure: 0, engine: engine)
		check(.character(.include(.any("a"))), "b",
			failure: 0, engine: engine)
		check(.sequence([.string("a"), .character(.include(.any("b")))]), "aX",
			failure: 1, engine: engine)
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func Unicodeの失敗位置は原文のScalar境界を指す(
		engine: TokenMatchingEngine,
	) {
		check(.string("é"), "ê", failure: 0, engine: engine)
		check(.string("日本"), "日語", failure: 3, engine: engine)
		check(.string("e\u{301}x"), "e\u{301}y",
			failure: 3, engine: engine)
		check(.string("kσx").ignoresCase(), "KΣy", failure: 5, engine: engine)
		check(.string("kσx").ignoresCase(), "KΣ", failure: 5, engine: engine)
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func 選択を巻き戻しても先の候補の最遠位置を保持する(
		engine: TokenMatchingEngine,
	) {
		check(.alternative([.string("abcd"), .string("ax")]), "abc!",
			failure: 3, engine: engine)
		check(.alternative([.string("ax"), .string("abcd")]), "abc!",
			failure: 3, engine: engine)
		check(.sequence([.string("abcd").repeat(0...1), .string("x")]), "abc!",
			failure: 3, engine: engine)
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func 反復内部と後続の失敗を巻き戻しても最遠位置を保持する(
		engine: TokenMatchingEngine,
	) {
		for behavior: TokenRepetitionBehavior in [.eager, .reluctant] {
			check(.string("ab").repeat(2..., behavior: behavior), "abaX",
				failure: 3, engine: engine)
			check(.sequence([.string("ab").repeat(0..., behavior: behavior), .string("!")]),
				"abaX", failure: 3, engine: engine)
			check(.sequence([.character(.include(.any("a"))).repeat(
				0..., behavior: behavior), .string("b")]),
				"aaaX", failure: 3, engine: engine)
		}
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func 部分入力の終端を越えず原文の失敗位置を返す(
		engine: TokenMatchingEngine,
	) {
		check(.string("kσz!").ignoresCase(), "xKΣz!", range: 1..<7,
			failure: 7, engine: engine)
		check(.string("abc!"), "xabc!", range: 1..<4,
			failure: 4, engine: engine)
	}

	private func check(
		_ pattern: TokenIR,
		_ input: String,
		range: Range<Int>? = nil,
		failure: Int,
		engine: TokenMatchingEngine,
		sourceLocation: Testing.SourceLocation = #_sourceLocation,
	) {
		let stream: TokenInputStream = .init(input, range: range)
		let result: TokenMatchResult
		let evaluated: TokenInputStream
		switch engine {
			case .matcher:
				var matcher: TokenMatcher = .init(
					stream: stream, maxRepetition: 65_535,
				)
				result = matcher.match(pattern)
				evaluated = matcher.stream
			case .vm, .optimizedVM:
				let compiler: TokenProgramCompiler = .init(
					optimizeSimpleRepetitions: engine == .optimizedVM,
				)
				var vm: TokenVM = .init(stream: stream, maxRepetition: 65_535)
				result = vm.match(compiler.compile(pattern))
				evaluated = vm.stream
		}
		let expected: String.Index = stream.input.base.utf8.index(
			stream.input.base.startIndex, offsetBy: failure,
		)
		#expect(result == .failure(expected),
			sourceLocation: sourceLocation)
		#expect(evaluated.cursor == stream.cursor, sourceLocation: sourceLocation)
	}

}
