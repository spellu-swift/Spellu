import SpelluCore
import SpelluLex


// 対象API: SourceStream.scan(grammar:label:patterns:)。
// 任意回数の試行失敗は直前へ戻り、成功済みの反復は保持する。
// 必須回数の不足は全体を不一致とし、呼び出し元の位置を保持する。
@Suite struct TokenBacktrackingTests {

	@Test(arguments: [
		(Amount.zeroOrMore, "_", ""),
		(.zeroOrOne, "_", ""),
		(.upToN(3), "_", ""),
		(.zeroOrMore, "_1_", "_1"),
		(.oneOrMore, "_1_", "_1"),
		(.nOrMore(1), "_1_", "_1"),
		(.range(1, 3), "_1_", "_1"),
		(.zeroOrMore, "_1_2_", "_1_2"),
		(.zeroOrMore, "_1_x", "_1"),
	])
	func 未完成の反復を消費しない(
		_ amount: Amount,
		_ input: String,
		_ expected: String,
	) throws {
		var stream: SourceStream = .init(.temporary(input))
		let node: SourceNode? = stream.scan(
			grammar: nil,
			label: "number",
			pattern:
				.sequence([
					.string("_"),
					.character(.include(.any(Array("0123456789".unicodeScalars)))),
				], amount: amount),
		)

		#expect(node?.string == expected)
		#expect(node?.range == 0..<expected.utf8.count)
		#expect(stream.offset == expected.utf8.count)
		#expect(stream.remain.first == "_")
	}

	@Test(arguments: [Amount.nOrMore(2), .exactly(2), .range(2, 3)])
	func 必須回数の途中失敗は不一致になる(
		_ amount: Amount,
	) {
		var stream: SourceStream = .init(.temporary("_1_"))
		let pattern: TokenIR = .sequence([
			.string("_"),
			.string("1"),
		], amount: amount)

		#expect(
			stream.scan(
				grammar: nil,
				label: .none,
				pattern: pattern,
			) == nil
		)
		#expect(stream.offset == 0)
	}

}


extension TokenBacktrackingTests {

	// 対象API: scan(patterns:)と各TokenBuilder。
	// 候補順、Group外への後戻り、反復の内部・外部の候補保持を確認する。
	@Test func Alternativeは最初の候補から試す() throws {
		try expectMatch(ChoiceOf { "a"; "ab" }, "ab", "a")
		try expectMatch(ChoiceOf { "ab"; "a" }, "ab", "ab")
	}

	@Test func 後続失敗時に成功済みAlternativeの次候補を試す() throws {
		try expectMatch(.sequence([ChoiceOf { "ab"; "a" }, .string("b")]), "ab", "ab")
		try expectMatch(.sequence([
			Sequence { Sequence { ChoiceOf { "ab"; "a" } } },
			.string("b"),
		]), "ab", "ab")
	}

	@Test func 三つ目の候補まで戻り全体失敗では入力位置を保つ() throws {
		let pattern: TokenIR = .sequence([
			ChoiceOf { "abc"; "ab"; "a" },
			.string("bc"),
		])
		try expectMatch(pattern, "abc", "abc")
		try expectMatch(pattern, "abx", nil)
	}

	@Test(arguments: [TokenRepetitionBehavior.eager, .reluctant])
	func 反復動作が後続のための消費量調整を決める(
		_ behavior: TokenRepetitionBehavior,
	) throws {
		let expected: String?
		= switch behavior {
			case .eager: "aaa"
			case .reluctant: "a"
			default: preconditionFailure("対象外の反復指定です")
		}
		try expectMatch(.sequence([
			"a".repeat(0..., behavior: behavior),
			.string("a"),
		]), "aaa", expected)
	}

	@Test func reluctantも後続の成立に必要な回数まで読む() throws {
		try expectMatch(.sequence([
			.string("<"),
			CharacterClass.all.repeat(0..., behavior: .reluctant),
			.string(">"),
		]), "<x><y>", "<x>")
		try expectMatch(.sequence([
			.string("<"),
			CharacterClass.all.repeat(0..., behavior: .eager),
			.string(">"),
		]), "<x><y>", "<x><y>")
	}

	@Test(arguments: [TokenRepetitionBehavior.eager, .reluctant])
	func 最小回数と最大回数を守る(
		_ behavior: TokenRepetitionBehavior,
	) throws {
		let pattern: TokenIR = Repeat(2...3, behavior: behavior) { "a" }
		try expectMatch(pattern, "a", nil)
		try expectMatch(pattern, "aaaa", behavior == .reluctant ? "aa" : "aaa")
	}

	@Test func 固定回数の反復でも内部Alternativeへ戻れる() throws {
		let body: TokenIR = ChoiceOf { "aa"; "a" }
		try expectMatch(.sequence([
			body.repeat(2...2), .string("a"),
		]), "aaa", "aaa")

	}


	@Test(arguments: [TokenRepetitionBehavior.eager, .reluctant],
		[TokenEngine.interpreter, .momojiri])
	func 反復上限を守り最小回数不足では失敗する(
		_ behavior: TokenRepetitionBehavior,
		_ engine: TokenEngine,
	) throws {
		try expectMatch(.sequence([
			"a".repeat(1..., behavior: behavior), .string("!"),
		]), "aaa!", nil, limit: 2, engine: engine)
		try expectMatch(.sequence([
			"a".repeat(3..., behavior: behavior),
		]), "aaa!", nil, limit: 2, engine: engine)
		try expectMatch(
			"a".repeat(0..., behavior: behavior),
			"aaa", "", limit: 0, engine: engine,
		)
	}

	@Test(arguments: [TokenRepetitionBehavior.eager, .reluctant],
		[TokenEngine.interpreter, .momojiri])
	func Groupの0回以上の反復は上限0でも空で成功する(
		_ behavior: TokenRepetitionBehavior,
		_ engine: TokenEngine,
	) throws {
		let pattern: TokenIR
		= .sequence([.string("a")]).repeat(0..., behavior: behavior)
		try expectMatch(pattern, "aaa!", "", limit: 0, engine: engine)
		try expectMatch(
			pattern, "aaa!", behavior == .reluctant ? "" : "aa",
			limit: 2, engine: engine,
		)
		try expectMatch(pattern, "!", "", limit: 2, engine: engine)
		try expectMatch(
			TokenIR.sequence([]).repeat(0..., behavior: behavior),
			"a", "", limit: 0, engine: engine,
		)
	}

	@Test(arguments: [TokenRepetitionBehavior.eager, .reluctant],
		[TokenEngine.interpreter, .momojiri])
	func Groupの1回以上の反復は上限0では失敗する(
		_ behavior: TokenRepetitionBehavior,
		_ engine: TokenEngine,
	) throws {
		let pattern: TokenIR
		= .sequence([.string("a")]).repeat(1..., behavior: behavior)
		try expectMatch(pattern, "aaa!", nil, limit: 0, engine: engine)
		try expectMatch(
			pattern, "aaa!", behavior == .reluctant ? "a" : "aa",
			limit: 2, engine: engine,
		)
		try expectMatch(pattern, "!", nil, limit: 2, engine: engine)
		let empty: TokenIR
		= .sequence([]).repeat(1..., behavior: behavior)
		try expectMatch(empty, "a", nil, limit: 0, engine: engine)
		try expectMatch(empty, "a", "", limit: 2, engine: engine)
	}

	@Test(arguments: [TokenRepetitionBehavior.eager, .reluctant])
	func 空成功する本体を無限に反復しない(
		_ behavior: TokenRepetitionBehavior,
	) throws {
		try expectMatch(.sequence([
			Repeat(0..., behavior: behavior) {}, .string("a"),
		]), "a", "a")
		try expectMatch(.sequence([
			Repeat(2...2, behavior: behavior) {}, .string("a"),
		]), "a", "a")
	}

	@Test func 空候補から消費する候補へ戻れる() throws {
		try expectMatch(.sequence([
			ChoiceOf { Sequence {}; "a" }.repeat(0...),
			.string("b"),
		]), "ab", "ab")
	}

	@Test func 後戻りしても大小文字設定とScalar位置を復元する() throws {
		try expectMatch(.sequence([
			Sequence {
				ChoiceOf { "ςb"; "σ" }
			}.ignoresCase(),
			.string("b"),
		]), "Σb", "Σb")
		try expectMatch(.sequence([
			"σ".ignoresCase().repeat(0...), .string("ς"),
		]), "Σς", "Σς")
		try expectMatch(.sequence([
			Sequence {
				ChoiceOf { "ab".ignoresCase(false); "a" }
			}.ignoresCase(),
			.string("B"),
		]), "AB", "AB")
	}

	@Test(arguments: [false, true])
	func 文字列照合はSourceの上限を越えない(
		_ caseInsensitive: Bool,
	) throws {
		var stream: SourceStream = .init(
			.temporary("abc", range: .character(0..<1)),
		)
		let node: SourceNode? = stream.scan(
			grammar: nil,
			label: .none,
			pattern: ChoiceOf { "ab"; "a" }.ignoresCase(caseInsensitive),
		)
		#expect(node?.string == "a")
		#expect(stream.offset == 1)
	}

	private func expectMatch(
		_ pattern: TokenIR,
		_ input: String,
		_ expected: String?,
		limit: Int? = nil,
		engine: TokenEngine = .momojiri,
	) throws {
		var stream: SourceStream = .init(
			.temporary(input),
			engine: engine,
			maxTokenRepetition: limit,
		)
		if let expected: String {
			let node: SourceNode? = stream.scan(
				grammar: nil, label: .none, pattern: pattern,
			)
			#expect(node?.string == expected)
			#expect(node?.range == 0..<expected.utf8.count)
			#expect(stream.offset == expected.utf8.count)
		}
		else {
			#expect(
				stream.scan(grammar: nil, label: .none, pattern: pattern)
				== nil
			)
			#expect(stream.offset == 0)
		}
	}

}
