@testable import SpelluCore
import SpelluLex


@Suite struct SourceStreamTests {
	
	@Test func range_1() throws {
		let stream = SourceStream(
			.temporary("abcdef")
		)
		
		#expect(stream.input == "abcdef")
		#expect(stream.offset == 0)
//		#expect(stream.current == "abcdef")
	}
	
	@Test func range_2() throws {
		let stream = SourceStream(
			.temporary("abcdef", range: .character(1..<3))
		)
		
		#expect(stream.input == "abcdef")
		#expect(stream.offset == 1)
//		#expect(stream.current == "bc")
	}
	
	@Test func range_3() throws {
		let stream = SourceStream(
			.temporary("abcdef", range: .character(1...3))
		)
		
		#expect(stream.offset == 1)
		#expect(stream.input == "abcdef")
//		#expect(stream.current == "bcd")
	}
	
	@Test func eol_1() throws {
		var stream = SourceStream(
			.temporary("\n")
		)
		
		let cursor = stream.match([.newline])
		
		#expect(stream.count(to: cursor.matchedEnd) == 1)
	}

	@Test func eol_2() throws {
		var stream = SourceStream(
			.temporary("\r")
		)
		
		let cursor = stream.match([.newline])
		
		#expect(stream.count(to: cursor.matchedEnd) == 1)
	}

	@Test func eol_3() throws {
		var stream = SourceStream(
			.temporary("\r\n")
		)
		
		let cursor = stream.match([.newline])
		
		#expect(stream.count(to: cursor.matchedEnd) == 2)
	}
	
	@Test func eol_4() throws {
		var stream = SourceStream(
			.temporary("")
		)
		
		let cursor = stream.match([.newline])
		
		#expect(stream.count(to: cursor.matchedEnd) == nil)
	}
	
	@Test func scan_lex_space() throws {
		var stream = SourceStream(
			.temporary("abc ")
		)

		let node = stream.scan(
			grammar: nil,
			label: .none,
			trivia: [.token(TokenIR("abc"))],
		)

		#expect(node?.substring == "abc")
		#expect(stream.offset == 3)
	}

	@Test func scan_lex_space_failure_continues() throws {
		var stream = SourceStream(
			.temporary(" abc")
		)

		let node = stream.scan(
			grammar: nil,
			label: .none,
			trivia: [
				.token(TokenIR("x")),
				.space,
			],
		)

		#expect(node?.string == " ")
		#expect(stream.offset == 1)
	}

	@Test func scan_token_string() throws {
		var stream = SourceStream(
			.temporary("abc ")
		)

		let node = stream.scan(
			grammar: nil,
			label: .none,
			pattern: .string("abc"),
		)

		#expect(node?.substring == "abc")
		#expect(stream.offset == 3)
	}

	@Test func scan_token_japanese_string() throws {
		var stream = SourceStream(
			.temporary("あいう ")
		)

		let node = stream.scan(
			grammar: nil,
			label: .none,
			pattern:.string("あいう")
		)

		#expect(node?.substring == "あいう")
		#expect(stream.offset == 9)
	}

	@Test func scan_token_alternative_group() throws {
		var stream = SourceStream(
			.temporary("abc")
		)

		let node = stream.scan(
			grammar: nil,
			label: .none,
			pattern: .sequence([
				.alternative([
					.sequence([TokenIR("a"), TokenIR("x")]),
					.sequence([TokenIR("a"), TokenIR("b")]),
				]),
				TokenIR("c"),
			]),
		)

		#expect(node?.substring == "abc")
		#expect(stream.offset == 3)
	}

	@Test func scan_token_group_repeat() throws {
		var stream = SourceStream(
			.temporary("abab")
		)

		let node = stream.scan(
			grammar: nil,
			label: .none,
			pattern:
				.sequence(
					[TokenIR("ab")],
					amount: .exactly(2),
				),
		)

		#expect(node?.substring == "abab")
		#expect(stream.offset == 4)
	}

	@Test func match_failure_restores_offset() throws {
		let stream = SourceStream(
			.temporary("abx")
		)

		let cursor = stream.match(
			.sequence([
				TokenIR("a"),
				TokenIR("b"),
				TokenIR("c"),
			]),
		)

		#expect(stream.count(to: cursor.matchedEnd) == nil)
		#expect(cursor == .failure(stream.input.index(
			stream.input.startIndex, offsetBy: 2,
		)))
		#expect(stream.offset == 0)
	}

	@Test func string_match() throws {
		var stream = SourceStream(
			.temporary(" SwIfT")
		)
		_ = stream.skip(count: 1)

		let cursor = stream.match(
			"swift",
			caseInsensitive: true,
		)

		#expect(stream.count(to: cursor.matchedEnd) == 5)
		#expect(stream.offset == 1)
	}

	@Test func SimpleCaseFoldingで文字列を照合する() throws {
		let stream = SourceStream(
			.temporary("SwIfT")
		)

		let cursor = stream.match(
			.string("swift", caseInsensitive: true),
		)

		#expect(stream.count(to: cursor.matchedEnd) == 5)
		#expect(stream.offset == 0)
	}

	@Test func SimpleCaseFoldingはシグマの異体を同じ文字として照合する() throws {
		let stream = SourceStream(
			.temporary("ς")
		)

		let cursor = stream.match(
			.string("Σ", caseInsensitive: true),
		)

		#expect(stream.count(to: cursor.matchedEnd) == "ς".utf8.count)
		#expect(stream.offset == 0)
	}

	@Test func SimpleCaseFoldingは複数文字への展開を行わない() throws {
		let stream = SourceStream(
			.temporary("ß")
		)

		let cursor = stream.match(
			.string("ss", caseInsensitive: true),
		)

		#expect(stream.count(to: cursor.matchedEnd) == nil)
		#expect(stream.offset == 0)
	}

	@Test func SimpleCaseFoldingで文字クラスを照合する() throws {
		let stream = SourceStream(
			.temporary("ς")
		)

		let cursor = stream.match(
			.character(.include(.any("σ"))).ignoresCase(true),
		)

		#expect(stream.count(to: cursor.matchedEnd) == "ς".utf8.count)
		#expect(stream.offset == 0)
	}

	@Test func グループのcaseInsensitiveを内部の文字列に適用する() throws {
		let stream = SourceStream(
			.temporary("SwIfT")
		)

		let cursor = stream.match(
			.sequence([.string("swift")]).ignoresCase(true),
		)

		#expect(stream.count(to: cursor.matchedEnd) == 5)
		#expect(stream.offset == 0)
	}

	@Test func グループの内部のcaseInsensitiveを適用する() throws {
		let stream = SourceStream(
			.temporary("SwIfT")
		)

		let cursor = stream.match(
			.sequence([
				.string("swift").ignoresCase(false)
			]).ignoresCase(true),
		)

		#expect(stream.count(to: cursor.matchedEnd) == nil)
		#expect(stream.offset == 0)
	}

	@Test func caseInsensitiveがfalseかnilなら大文字小文字を区別する() throws {
		let patterns: [TokenIR] = [
			.string("swift"),
			.string("swift", caseInsensitive: false),
		]

		for pattern in patterns {
			let stream = SourceStream(
				.temporary("Swift")
			)

			let cursor = stream.match(pattern)

			#expect(stream.count(to: cursor.matchedEnd) == nil)
			#expect(stream.offset == 0)
		}
	}

}
