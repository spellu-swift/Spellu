import SpelluRegex


@Suite struct SpelluRegexEvaluationTests {

	@available(macOS 15, iOS 18, *)
	@Test(arguments: [
		("a|ab", "ab", "a"), ("ab|a", "ab", "ab"),
		("(ab|a)b", "ab", "ab"), ("a*a", "aaa", "aaa"),
		("a*?a", "aaa", "a"), ("a{2,3}", "aaaa", "aaa"),
		("a{2,3}?", "aaaa", "aa"), ("a{2,}", "aaaa", "aaaa"),
		("a?", "a", "a"), ("a??", "a", ""),
		("a+?", "aaa", "a"), ("a{0}", "a", ""),
		("a{2}", "aaa", "aa"), ("(?:a|ab)c", "abc", "abc"),
		("a||b", "b", ""), ("(?:)*", "", ""),
		("(?:){2,3}", "", ""), ("(a?)*", "", ""),
	])
	@available(macOS 15, iOS 18, *)
	func 記述順と貪欲非貪欲の再試行を守る(
		_ pattern: String,
		_ input: String,
		_ expected: String,
	) throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(pattern)
		#expect(try regex.prefixMatch(in: input)?.substring == Substring(expected))
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 全体一致では先に成功した選択肢へ戻れる() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init("a|ab")
		#expect(try regex.wholeMatch(in: "ab")?.substring == "ab")
		#expect(try SpelluRegex("a*?").wholeMatch(in: "aaa")?.substring == "aaa")
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 捕捉は開き括弧順で反復と再試行で復元する() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init("((a)|(b))*")
		@available(macOS 15, iOS 18, *)
		let result: Match = try #require(try regex.wholeMatch(in: "ab"))
		#expect(result.captures.count == 3)
		#expect(result.input[try #require(result.captures[0])] == "b")
		#expect(result.captures[1] == nil)
		#expect(result.input[try #require(result.captures[2])] == "b")
		@available(macOS 15, iOS 18, *)
		let retry: Match = try #require(
			try SpelluRegex("(a)|(ab)").wholeMatch(in: "ab")
		)
		#expect(retry.captures[0] == nil)
		#expect(retry.input[try #require(retry.captures[1])] == "ab")
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 任意空反復は捕捉を更新せず必須空反復は捕捉する() throws {
		@available(macOS 15, iOS 18, *)
		let optional: Match = try #require(
			try SpelluRegex("(a?)*").wholeMatch(in: "")
		)
		#expect(optional.captures[0] == nil)
		@available(macOS 15, iOS 18, *)
		let required: Match = try #require(
			try SpelluRegex("(a?)+").wholeMatch(in: "")
		)
		@available(macOS 15, iOS 18, *)
		let empty: Range<String.Index> = try #require(required.captures[0])
		#expect(empty.isEmpty)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func Scalar単位で評価し正規等価比較をしない() throws {
		#expect(try SpelluRegex(".").wholeMatch(in: "🙂") != nil)
		#expect(try SpelluRegex(".").wholeMatch(in: "e\u{301}") == nil)
		#expect(try SpelluRegex("..").wholeMatch(in: "e\u{301}") != nil)
		#expect(try SpelluRegex("é").wholeMatch(in: "e\u{301}") == nil)
		#expect(try SpelluRegex(#"\u{1F600}+"#).wholeMatch(in: "😀😀") != nil)
		#expect(try SpelluRegex(#"\uD83D\uDE00"#).wholeMatch(in: "😀") != nil)
		#expect(try SpelluRegex(#"\u{000000061}"#).wholeMatch(in: "a") != nil)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 行境界とdotと空patternを区別する() throws {
		#expect(try SpelluRegex(".").wholeMatch(in: "\n") == nil)
		#expect(try SpelluRegex(".", options: .init(
			dotMatchesNewlines: true
		)).wholeMatch(in: "\n") != nil)
		#expect(try SpelluRegex("a$").prefixMatch(in: "a\n") == nil)
		#expect(try SpelluRegex("^b$", options: .init(
			multiline: true
		)).firstMatch(in: "a\r\nb\u{2028}c")?.substring == "b")
		#expect(try SpelluRegex("").wholeMatch(in: "") != nil)
		#expect(try SpelluRegex("").wholeMatch(in: "a") == nil)
		#expect(try SpelluRegex("$").firstMatch(in: "🙂")?.substring == "")
	}

}
