import SpelluRegex


@Suite struct SpelluRegexStage2SemanticsTests {

	@available(macOS 15, iOS 18, *)
	@Test(arguments: [
		(#"(a)\1"#, "aa", true), (#"(a)\1"#, "ab", false),
		(#"\1(a)"#, "a", true), (#"(\1a)"#, "a", true),
		(#"(a|(b))\2"#, "a", true), (#"(a|(b))\2"#, "bb", true),
		(#"(?<x>a)\k<x>"#, "aa", true),
		(#"\k<x>(?<x>a)"#, "a", true),
		(#"(?<x>\k<x>a)"#, "a", true),
		(#"(?:(?<x>a)|(?<x>b))+\k<x>"#, "abb", true),
		(#"(?:(?<x>a)|(?<x>b))+\k<x>"#, "aba", false),
		(#"(?<x>a)|(?:(?<x>b)|(?<x>c))"#, "c", true),
		(#"(?=(a+))a*b\1"#, "aaba", false),
		(#"(?!((a)))\1b"#, "b", true),
		(#"(?=(a))\1"#, "a", true),
		(#"(?!(a|ab))b"#, "b", true),
		(#"(?!(a|ab))a"#, "a", false),
		(#"(?=(?!b)a)(?!(?!a))a"#, "a", true),
		(#"(?i:a)b"#, "Ab", true), (#"(?i:a)b"#, "AB", false),
		(#"(?i:a(?-i:b)c)"#, "AbC", true),
		(#"(?i:a(?-i:b)c)"#, "ABC", false),
		(#"(?i-:a)"#, "A", true), (#"(?-i:a)"#, "A", false),
		(#"(?s:.)"#, "\n", true), (#"(?s:.)."#, "\n\n", false),
		(#"(?i:(a)\1)"#, "aA", true),
		(#"(?i:(a))(?-i:\1)"#, "aA", false),
	])
	@available(macOS 15, iOS 18, *)
	func 第2段階の照合意味論を守る(
		_ pattern: String,
		_ input: String,
		_ matched: Bool,
	) throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(pattern, options: .init(
			characterSemantics: .ecmaScript2026
		))
		#expect((try regex.wholeMatch(in: input) != nil) == matched)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 多桁の捕捉番号を一つの参照として解決する() throws {
		@available(macOS 15, iOS 18, *)
		let pattern: String = String(repeating: "(a)", count: 12) + #"\12"#
		#expect(try SpelluRegex(pattern).wholeMatch(
			in: String(repeating: "a", count: 13)
		) != nil)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 肯定先読みは位置を戻して捕捉を保持し内部へ戻らない() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(#"(?=(?<x>a+))a*b\k<x>"#)
		@available(macOS 15, iOS 18, *)
		let match: Match = try #require(try regex.firstMatch(in: "baaabac"))
		#expect(match.substring == "aba")
		#expect(match.capture(named: "x") == "a")
		@available(macOS 15, iOS 18, *)
		let beyond: Match = try #require(try SpelluRegex("(?=(abc))a")
			.prefixMatch(in: "abc"))
		#expect(beyond.substring == "a")
		#expect(beyond.input[try #require(beyond.captures[0])] == "abc")
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 否定先読みと外側の失敗から捕捉を復元する() throws {
		@available(macOS 15, iOS 18, *)
		let negative: Match = try #require(try SpelluRegex(
			#"(?!(?<no>x))(?<yes>a)"#
		).wholeMatch(in: "a"))
		#expect(negative.capture(named: "no") == nil)
		#expect(negative.capture(named: "yes") == "a")
		@available(macOS 15, iOS 18, *)
		let retry: Match = try #require(try SpelluRegex(
			#"(?=(?<discard>a))b|(?<keep>a)"#
		).wholeMatch(in: "a"))
		#expect(retry.capture(named: "discard") == nil)
		#expect(retry.capture(named: "keep") == "a")
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func word境界は選んだセットと局所的な大小無視に従う() throws {
		for semantics: CharacterSemantics in [.spellu, .ecmaScript2026] {
			@available(macOS 15, iOS 18, *)
			let options: Options = .init(characterSemantics: semantics)
			#expect(try SpelluRegex(#"\B"#, options: options)
				.wholeMatch(in: "") != nil)
			#expect(try SpelluRegex(#"\bword\b"#, options: options)
				.firstMatch(in: "a word!")?.substring == "word")
			#expect((try SpelluRegex(#"\b日本\b"#, options: options)
				.wholeMatch(in: "日本") != nil) == (semantics == .spellu))
		}
		@available(macOS 15, iOS 18, *)
		let options: Options = .init(characterSemantics: .ecmaScript2026)
		#expect(try SpelluRegex(#"(?i:\bK\b)"#, options: options)
			.wholeMatch(in: "K") != nil)
		#expect(try SpelluRegex(#"\bK\b"#, options: options)
			.wholeMatch(in: "K") == nil)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 局所修飾子は入れ子と再試行と先読みから復元する() throws {
		@available(macOS 15, iOS 18, *)
		let options: Options = .init(ignoresCase: true)
		#expect(try SpelluRegex("(?-i:a)b", options: options)
			.wholeMatch(in: "aB") != nil)
		#expect(try SpelluRegex("(?i:a)c|b").wholeMatch(in: "B") == nil)
		#expect(try SpelluRegex("(?=(?i:a))a").wholeMatch(in: "A") == nil)
		@available(macOS 15, iOS 18, *)
		let multiline: Match? = try SpelluRegex("(?m:^b$)")
			.firstMatch(in: "a\nb\nc")
		#expect(multiline?.substring == "b")
		#expect(try SpelluRegex("(?m:^b$)^c").firstMatch(in: "a\nb\nc") == nil)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 名前と参照に正規等価比較を持ち込まない() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(#"(?<é>é)(?<e\u0301>e\u0301)\k<é>"#)
		#expect(try regex.wholeMatch(in: "ée\u{301}é") != nil)
		#expect(try regex.wholeMatch(in: "ée\u{301}e\u{301}") == nil)
		#expect(try SpelluRegex(#"(?i:(?<x>k)\k<x>)"#)
			.wholeMatch(in: "kK") != nil)
	}

}
