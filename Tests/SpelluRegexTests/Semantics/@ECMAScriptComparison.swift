import JavaScriptCore
import SpelluRegex


/// 対応構文について、実際のECMAScript uモードと照合・捕捉を比較する。
/// UTF-16位置のAPI互換は目的にせず、結果を同じ位置表現へ換算する。
@Suite struct SpelluRegexECMAScriptComparisonTests {

	@available(macOS 15, iOS 18, *)
	@Test
	func 反復と選択と捕捉をJavaScriptのuモードと比較する() throws {
		@available(macOS 15, iOS 18, *)
		let context: JSContext = try #require(JSContext())
		context.evaluateScript(#"""
		function compare(pattern, input, mode, flags) {
		    const source = mode === 'whole'
		        ? '(?:' + pattern + ')(?![\\s\\S])' : pattern;
		    const re = new RegExp(source, 'u' + flags
		        + (mode === 'search' ? '' : 'y'));
		    const m = re.exec(input);
		    return m === null ? null : [String(m.index)].concat(
		        Array.from(m, x => x === undefined ? '<undefined>' : x));
		}
		"""#)
		@available(macOS 15, iOS 18, *)
		let function: JSValue = try #require(
			context.objectForKeyedSubscript("compare")
		)
		@available(macOS 15, iOS 18, *)
		let patterns: [String] = [
			"", "a|ab", "ab|a", "(ab|a)b", "a*a", "a*?a", "a?",
			"(a?)*", "(a?)+", "(a?){2,3}", "(a?){2,3}?",
			"((a)|(b))*", "((a)|(b)){0,3}", "((a?)*)*",
			"((a?)*)+?", "(?:(a)|b)+", "(a|(b))*", "(a|ab)*b",
			"([ab]+?)(b*)", "(a*?)(a*)", "(?:|a)*b", "(?:a|)*b",
			"(?:a*)*b", "((a)|(bc))*", "[^a-c]+", "[a-c-]*",
			"[--a]", "[-a-c]", "[a-b--c]", "[a-b-c-d]",
			"^a$", "a$", ".*?", "(..)+?", #"\d+"#, #"\w*"#,
			#"\p{L}+"#,
			#"(a)\1"#, #"\1(a)"#, #"(\1a)"#, #"(a|ab)\1"#,
			#"(a|(b))\2"#, #"(?<x>a)\k<x>"#,
			#"(?:(?<x>a)|(?<x>b))+\k<x>"#,
			#"\k<x>(?<x>a)"#, #"(?<x>\k<x>a)"#,
			#"(?=(a+))a*b\1"#, #"(.*?)a(?!(a+)b\2c)\2(.*)"#,
			#"(?=(?=(a+))a*)\1"#, #"(?=(a))b|(a)"#,
			#"(?!(a|ab))b"#, #"(?!(?!(a)))a"#, #"((?=(a))a)*"#,
			#"(?!(a))(?:b|\1)"#, #"(?=(a))(?!(b))\1"#,
			#"\b(a*)\b"#, #"\Ba+\B"#, #"\B"#, #"\bK\b"#,
			#"(?i:a)b"#, #"(?i:a(?-i:b)c)"#, #"(?i-:a)"#,
			#"(?-i:a)b"#, #"(?s:.)"#, #"(?s:.)."#,
			#"(?i:(a)\1)"#, #"(?i:(a))(?-i:\1)"#,
			#"(?=(?i:a))a"#, #"(?i:a)c|b"#, #"(?m:^b$)"#,
			#"(?im-s:^a.$)"#, #"(?i:\bK\b)"#,
		]
		// JavaScriptCoreはPとiの組合せで、2026のuモードと
		// 異なる結果を返す。この組合せは標準の意味論を直接検査する
		// CharacterTestsへ分離し、ここでは比較の基準にしない。
		@available(macOS 15, iOS 18, *)
		let inputs: [String] = [
			"", "a", "aa", "aaa", "ab", "abb", "bab", "aba", "bc",
			"abc", "abca", "bbbb", "baaabac", "aaba", "aA", "AB",
			"1", "K", "A", "a\nb", "🙂", "e\u{301}",
		]
		for flags: String in ["", "i", "m", "s"] {
			@available(macOS 15, iOS 18, *)
			let options: Options = .init(
				characterSemantics: .ecmaScript2026,
				ignoresCase: flags == "i", multiline: flags == "m",
				dotMatchesNewlines: flags == "s",
			)
			for pattern: String in patterns {
				@available(macOS 15, iOS 18, *)
				let regex: SpelluRegex = try .init(pattern, options: options)
				for input: String in inputs {
					for mode: String in ["prefix", "whole", "search"] {
						@available(macOS 15, iOS 18, *)
						let expected: JSValue = try #require(function.call(
							withArguments: [pattern, input, mode, flags]
						))
						#expect(context.exception == nil)
						@available(macOS 15, iOS 18, *)
						let match: Match?
						switch mode {
							case "whole": match = try regex.wholeMatch(in: input)
							case "prefix": match = try regex.prefixMatch(in: input)
							default: match = try regex.firstMatch(in: input)
						}
						@available(macOS 15, iOS 18, *)
						let actual: [String]?
						if let match {
							@available(macOS 15, iOS 18, *)
							let index: Int = input.utf16.distance(
								from: input.startIndex, to: match.range.lowerBound,
							)
							actual = [String(index), String(match.substring)]
								+ match.captures.map {
									$0.map { String(match.input[$0]) } ?? "<undefined>"
								}
						} else { actual = nil }
						@available(macOS 15, iOS 18, *)
						let values: [String]? = expected.isNull
							? nil : expected.toArray() as? [String]
						#expect(actual == values,
							"pattern=\(pattern) flags=\(flags) mode=\(mode) input=\(input)")
					}
				}
			}
		}
	}

}
