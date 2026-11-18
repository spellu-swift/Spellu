import Spellu
@testable import SpelluRegex


/// 公開入口: RegexGrammar.default／expression、SpelluRegex.init。
/// u構文の字句境界、空成功、静的検証、未対応機能を検査する。
@Suite struct SpelluRegexGrammarTests {

	@available(macOS 15, iOS 18, *)
	@Test(arguments: [
		"", "a", "a|", "|a", "a||b", "()", "(?:)", "a{2,3}?",
		"[]", "[^]", "[-a]", "[a-]", "[[]", "[^a-z]", "a b\nc",
		#"\u{1F600}"#, #"\uD83D\uDE00"#, #"\x61\cA\0"#,
		#"[\b\-\]]"#, #"\p{gc=Lu}"#, #"\P{Cs}"#,
		#"\b\B"#, "(?=a)", "(?!a)", "(?<x>a)", "(?i:a)",
	])
	@available(macOS 15, iOS 18, *)
	func uモードの構文と静的制約を受理する(_ pattern: String) throws {
		_ = try SpelluRegex(pattern)
	}

	@available(macOS 15, iOS 18, *)
	@Test(arguments: [
		"(", "a)", "[", "a**", "*a", "a{2,1}", "a{", "a{,2}",
		"^*", "$+", #"\"#, #"\a"#, #"\u"#, #"\xZ1"#,
		#"\u{110000}"#, #"\01"#, #"[z-a]"#, #"[a-\d]"#,
		#"\p{noSuchProperty}"#, #"\p{gc=letter}"#,
		#"\p{Script=}"#, #"\u{ABCDEF000000}"#,
	])
	@available(macOS 15, iOS 18, *)
	func 不正な構文を拒否する(_ pattern: String) {
		#expect(throws: (any Error).self) { try SpelluRegex(pattern) }
	}

	@available(macOS 15, iOS 18, *)
	@Test(arguments: [
		"(?<=a)", "(?<!a)", #"\uD800"#,
		#"\p{Script=Greek}"#, #"\p{RGI_Emoji}"#,
	])
	@available(macOS 15, iOS 18, *)
	func 未対応機能を黙って評価しない(_ pattern: String) {
		#expect(throws: (any Error).self) { try SpelluRegex(pattern) }
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 文法をv2で単独利用できる() throws {
		for strategy: TreeStrategy in [.asis, .compact] {
			@available(macOS 15, iOS 18, *)
			let spellu: Spellu = try .init(
				on: [RegexGrammar.default],
			)
			@available(macOS 15, iOS 18, *)
			let tree: SourceNode
			= try spellu.parse(
				.temporary("(a|b)*?"),
				method: .whole,
				strategy: strategy,
				as: RegexGrammar.$expression,
			)
			#expect(tree.string == "(a|b)*?")
		}
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func エラーはpattern内のUTF8範囲を持つ() throws {
		do {
			_ = try SpelluRegex("🙂[z-a]")
			Issue.record("不正な範囲を受理しました")
		} catch let SpelluRegexError.invalidPattern(range, _) {
			#expect(range == 5..<8)
		}
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 構文とASTの資源上限を区別する() {
		@available(macOS 15, iOS 18, *)
		let cases: [(String, RegexLimits)] = [
			("aa", .init(maximumPatternScalars: 1)),
			("((a))", .init(maximumNesting: 1)),
			("a", .init(maximumNodes: 1)),
			("()()", .init(maximumCaptures: 1)),
			("a{999999999999999999999}", .init()),
		]
		for (pattern, limits): (String, RegexLimits) in cases {
			#expect(throws: (any Error).self) {
				try SpelluRegex(pattern, options: .init(limits: limits))
			}
		}
	}

}
