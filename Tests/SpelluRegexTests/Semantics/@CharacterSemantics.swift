import SpelluRegex


@Suite struct SpelluRegexCharacterTests {

	@available(macOS 15, iOS 18, *)
	@Test
	func 同じ構文を文字クラスのセットで切り替える() throws {
		for pattern: String in [#"\d"#, #"[\d]"#] {
			@available(macOS 15, iOS 18, *)
			let spellu: SpelluRegex = try .init(pattern)
			@available(macOS 15, iOS 18, *)
			let ecma: SpelluRegex = try .init(pattern, options: .init(
				characterSemantics: .ecmaScript2026
			))
			#expect(try spellu.wholeMatch(in: "３") != nil)
			#expect(try ecma.wholeMatch(in: "３") == nil)
			#expect(try ecma.wholeMatch(in: "3") != nil)
		}
		#expect(try SpelluRegex(#"\w+"#).wholeMatch(in: "日本語") != nil)
		#expect(try SpelluRegex(#"\w+"#, options: .init(
			characterSemantics: .ecmaScript2026
		)).wholeMatch(in: "日本語") == nil)
		#expect(try SpelluRegex(#"\s"#).wholeMatch(in: "\u{FEFF}") == nil)
		#expect(try SpelluRegex(#"\s"#, options: .init(
			characterSemantics: .ecmaScript2026
		)).wholeMatch(in: "\u{FEFF}") != nil)
	}

	@available(macOS 15, iOS 18, *)
	@Test(arguments: [
		(#"[a-cx-z-]+"#, "az-", true), (#"[a-cx-z-]+"#, "q", false),
		(#"[^a]+"#, "bc", true), (#"[^a]+"#, "ab", false),
		(#"[]"#, "a", false), (#"[^]"#, "🙂", true),
		(#"\D+"#, "abc", true), (#"\W"#, "!", true),
		(#"\S"#, "a", true), (#"[\b]"#, "\u{8}", true),
		(#"\cA\x62\u0063"#, "\u{1}bc", true),
		(#"\p{L}+"#, "日本語", true), (#"\p{gc=Nd}"#, "３", true),
		(#"\p{ASCII}"#, "a", true), (#"\p{Any}"#, "😀", true),
		(#"\p{Assigned}"#, "\u{378}", false),
		(#"\p{Cs}"#, "a", false), (#"\P{Cs}"#, "😀", true),
		(#"[\uD7FF-\uE000]"#, "\u{E000}", true),
		(#"\p{Alpha}"#, "a", true), (#"\p{space}"#, " ", true),
	])
	@available(macOS 15, iOS 18, *)
	func 文字集合とescapeを評価する(
		_ pattern: String,
		_ input: String,
		_ expected: Bool,
	) throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(pattern, options: .init(
			characterSemantics: .ecmaScript2026
		))
		#expect((try regex.wholeMatch(in: input) != nil) == expected)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func SimpleCaseFoldingと否定の順序を守る() throws {
		@available(macOS 15, iOS 18, *)
		let options: Options = .init(
			characterSemantics: .ecmaScript2026, ignoresCase: true,
		)
		#expect(try SpelluRegex("k", options: options).wholeMatch(in: "K") != nil)
		#expect(try SpelluRegex("[a-z]", options: options).wholeMatch(in: "ſ") != nil)
		#expect(try SpelluRegex("[^a]", options: options).wholeMatch(in: "A") == nil)
		#expect(try SpelluRegex(#"\w"#, options: options).wholeMatch(in: "K") != nil)
		#expect(try SpelluRegex(#"\W"#, options: options).wholeMatch(in: "K") == nil)
		#expect(try SpelluRegex(#"\P{Lowercase_Letter}"#, options: options)
			.wholeMatch(in: "a") != nil)
		// ECMA-262 2026: Pの補集合をfoldし、外側の^は照合後に反転。
		#expect(try SpelluRegex(#"[^\P{Ll}]"#, options: options)
			.wholeMatch(in: "a") == nil)
		#expect(try SpelluRegex("ß", options: options).wholeMatch(in: "ss") == nil)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func ECMAScript名とSpellu固有のプロパティ別名を分離する() throws {
		#expect(try SpelluRegex(#"\p{Other_Alphabetic}"#)
			.wholeMatch(in: "a") != nil)
		#expect(throws: (any Error).self) {
			try SpelluRegex(#"\p{Other_Alphabetic}"#, options: .init(
				characterSemantics: .ecmaScript2026
			))
		}
		for semantics: CharacterSemantics in [.spellu, .ecmaScript2026] {
			#expect(try SpelluRegex(#"\u{61}"#, options: .init(
				characterSemantics: semantics
			)).wholeMatch(in: "a") != nil)
		}
	}

}
