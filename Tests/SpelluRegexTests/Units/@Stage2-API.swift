import SpelluRegex


/// 新規公開API: Match.captureNames／range(ofCapture:)／capture(named:)。
/// 正常系・未参加・空捕捉・未知名・Unicode符号列の区別を検査する。
@Suite struct SpelluRegexStage2APITests {

	@available(macOS 15, iOS 18, *)
	@Test
	func 名前による捕捉を取得する() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(#"(?<first>a)(?<empty>)(?<absent>b)?"#)
		@available(macOS 15, iOS 18, *)
		let match: Match = try #require(try regex.wholeMatch(in: "a"))
		#expect(match.captureNames == ["first", "empty", "absent"])
		#expect(match.capture(named: "first") == "a")
		#expect(match.range(ofCapture: "first") == match.captures[0])
		#expect(match.capture(named: "empty") == "")
		#expect(match.range(ofCapture: "empty")?.isEmpty == true)
		#expect(match.capture(named: "absent") == nil)
		#expect(match.range(ofCapture: "absent") == nil)
		#expect(match.capture(named: "unknown") == nil)
		#expect(match.range(ofCapture: "unknown") == nil)
		@available(macOS 15, iOS 18, *)
		let unnamed: Match = try #require(try SpelluRegex("a").wholeMatch(in: "a"))
		#expect(unnamed.captureNames.isEmpty)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 捕捉名を復号し正規等価な符号列を別名として保つ() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(
			#"(?<\u{E9}>a)(?<e\u0301>b)(?<\uD835\uDC9C>c)"#
		)
		@available(macOS 15, iOS 18, *)
		let match: Match = try #require(try regex.wholeMatch(in: "abc"))
		#expect(match.captureNames.map { Array($0.unicodeScalars) } == [
			Array("é".unicodeScalars), Array("e\u{301}".unicodeScalars),
			Array("𝒜".unicodeScalars),
		])
		#expect(match.capture(named: "é") == "a")
		#expect(match.capture(named: "e\u{301}") == "b")
		#expect(match.capture(named: "𝒜") == "c")
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 別Alternativeの同名捕捉を一つの公開名にまとめる() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init(#"(?:(?<x>a)|(?<\u0078>b))\k<x>"#)
		for input: String in ["aa", "bb"] {
			@available(macOS 15, iOS 18, *)
			let match: Match = try #require(try regex.wholeMatch(in: input))
			#expect(match.captureNames == ["x"])
			#expect(match.capture(named: "x") == input.prefix(1))
			#expect(match.range(ofCapture: "x") != nil)
		}
	}

	@available(macOS 15, iOS 18, *)
	@Test(arguments: [
		#"\1"#, #"(a)\2"#, #"\k<missing>"#, #"(?<x>a)\k<y>"#,
		#"\999999999999999999999999"#, #"[\1]"#, #"[\B]"#,
		#"(?<1x>a)"#, #"(?<x-y>a)"#, #"(?<\x61>a)"#,
		#"(?<\uD800>a)"#, #"(?<\u{110000}>a)"#, #"(?<>a)"#,
		#"(?<x>a)(?<x>b)"#, #"(?<x>(?<x>a))"#,
		#"(?<x>a)(?!(?<x>b))"#, #"(?<x>a)|(?<x>b)(?<x>c)"#,
		#"(?i-i:a)"#, #"(?ii:a)"#, #"(?-mm:a)"#, #"(?-:a)"#,
		#"(?i--s:a)"#, #"(?u:a)"#, #"(?=a)*"#, #"\b+"#,
	])
	@available(macOS 15, iOS 18, *)
	func 第2段階の静的制約に違反するパターンを拒否する(
		_ pattern: String,
	) {
		#expect(throws: (any Error).self) { try SpelluRegex(pattern) }
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 先読みと参照も共通の実行予算を使う() throws {
		@available(macOS 15, iOS 18, *)
		let limited: SpelluRegex = try .init(
			"(?=(?=(?=a)))a",
			options: .init(limits: .init(maximumBacktracking: 2)),
		)
		#expect(throws: (any Error).self) { try limited.wholeMatch(in: "a") }
		@available(macOS 15, iOS 18, *)
		let reference: SpelluRegex = try .init(
			#"(a{20})\1"#,
			options: .init(limits: .init(maximumSteps: 100)),
		)
		#expect(throws: (any Error).self) {
			try reference.wholeMatch(in: String(repeating: "a", count: 40))
		}
	}

}
