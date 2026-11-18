import SpelluRegex


/// 公開API: Options／RegexLimitsの全設定、pattern／options、
/// wholeMatch／prefixMatch／firstMatchとStringProtocol拡張、Matchの全属性。
@Suite struct SpelluRegexAPITests {

	@available(macOS 15, iOS 18, *)
	@Test
	func 設定とpatternを保持する() throws {
		@available(macOS 15, iOS 18, *)
		let limits: RegexLimits = .init(
			maximumPatternScalars: 100, maximumNesting: 10,
			maximumNodes: 200, maximumCaptures: 20,
			maximumInputScalars: 300, maximumSteps: 400,
			maximumBacktracking: 50,
		)
		@available(macOS 15, iOS 18, *)
		let options: Options = .init(
			characterSemantics: .ecmaScript2026,
			ignoresCase: true, multiline: true,
			dotMatchesNewlines: true, limits: limits,
		)
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init("abc", options: options)
		#expect(regex.pattern == "abc")
		#expect(regex.options.characterSemantics == .ecmaScript2026)
		#expect(regex.options.ignoresCase)
		#expect(regex.options.multiline)
		#expect(regex.options.dotMatchesNewlines)
		#expect(limits.maximumPatternScalars == 100)
		#expect(limits.maximumNesting == 10)
		#expect(limits.maximumNodes == 200)
		#expect(limits.maximumCaptures == 20)
		#expect(limits.maximumInputScalars == 300)
		#expect(limits.maximumSteps == 400)
		#expect(limits.maximumBacktracking == 50)
		#expect(Options().characterSemantics == .spellu)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 不正な上限を拒否する() {
		@available(macOS 15, iOS 18, *)
		let cases: [RegexLimits] = [
			.init(maximumPatternScalars: 0), .init(maximumNesting: 0),
			.init(maximumNesting: 257), .init(maximumNodes: -1),
			.init(maximumCaptures: 0), .init(maximumInputScalars: 0),
			.init(maximumSteps: 0), .init(maximumBacktracking: 0),
		]
		for limits: RegexLimits in cases {
			#expect(throws: SpelluRegexError.invalidLimits) {
				try SpelluRegex("", options: .init(limits: limits))
			}
		}
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 三つの照合入口と拡張を使える() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init("a+")
		#expect(try regex.wholeMatch(in: "aa")?.substring == "aa")
		#expect(try regex.wholeMatch(in: "aab") == nil)
		#expect(try regex.prefixMatch(in: "aab")?.substring == "aa")
		#expect(try regex.prefixMatch(in: "baa") == nil)
		#expect(try regex.firstMatch(in: "baa")?.substring == "aa")
		#expect(try regex.firstMatch(in: "bbb") == nil)
		#expect(try "aa".wholeMatch(of: regex)?.substring == "aa")
		#expect(try "aab".prefixMatch(of: regex)?.substring == "aa")
		#expect(try "baa".firstMatch(of: regex)?.substring == "aa")
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func Substringの位置と捕捉範囲を保持する() throws {
		@available(macOS 15, iOS 18, *)
		let text: String = "前🙂e\u{301}後"
		@available(macOS 15, iOS 18, *)
		let start: String.Index = text.unicodeScalars.index(
			text.startIndex, offsetBy: 1,
		)
		@available(macOS 15, iOS 18, *)
		let end: String.Index = text.index(before: text.endIndex)
		@available(macOS 15, iOS 18, *)
		let input: Substring = text[start..<end]
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init("(🙂)(e)(.)")
		@available(macOS 15, iOS 18, *)
		let match: Match = try #require(try regex.wholeMatch(in: input))
		#expect(match.input.startIndex == start)
		#expect(match.range == start..<end)
		#expect(match.substring == input)
		#expect(match.captures.count == 3)
		#expect(input[try #require(match.captures[0])] == "🙂")
		#expect(input[try #require(match.captures[2])] == "\u{301}")
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 一つのProgramを繰り返し利用できる() throws {
		@available(macOS 15, iOS 18, *)
		let regex: SpelluRegex = try .init("(a)?b")
		#expect(try regex.wholeMatch(in: "ab")?.captures[0] != nil)
		@available(macOS 15, iOS 18, *)
		let match: Match = try #require(try regex.wholeMatch(in: "b"))
		#expect(match.captures[0] == nil)
	}

	@available(macOS 15, iOS 18, *)
	@Test
	func 実行上限を不一致として隠さない() throws {
		@available(macOS 15, iOS 18, *)
		let cases: [(String, String, RegexLimits)] = [
			("a", "aa", .init(maximumInputScalars: 1)),
			("a+", "aaa", .init(maximumSteps: 2)),
			("a*", "aaa", .init(maximumBacktracking: 1)),
			("z", "aaaaaa", .init(maximumSteps: 5)),
		]
		for (pattern, input, limits): (String, String, RegexLimits) in cases {
			@available(macOS 15, iOS 18, *)
			let regex: SpelluRegex = try .init(
				pattern, options: .init(limits: limits),
			)
			#expect(throws: (any Error).self) {
				try regex.firstMatch(in: input)
			}
		}
	}

}
