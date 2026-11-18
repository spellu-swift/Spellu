@testable import SpelluCore
import SpelluLex


@Suite(.serialized)
struct SourceStreamUnicodeSpacesTests {

	@Test
	func 空白コメント改行を混在したまま読み飛ばす() {
		let prefix: String
		= " \t-- one\r\n-- two\n "
		var stream: SourceStream
		= .init(.temporary(prefix + "x"))
		let node = stream.scan(grammar: nil, label: .none, trivia: commentSpaces)
		#expect(node?.string == prefix)
		#expect(node?.range == 0..<prefix.utf8.count)
		#expect(stream.offset == prefix.utf8.count)
		#expect(stream.current == "x")
	}

	@Test
	func 失敗した空白候補の途中一致は次の候補へ持ち越さない() {
		var stream: SourceStream
		= .init(.temporary("abx"))
		let count = stream.consume(trivia: [
			.token(Sequence { "ab"; "z" }),
			.string("ab"),
		])
		#expect(count == 2)
		#expect(stream.offset == 2)
		#expect(stream.current == "x")
	}

	@Test
	func 空一致する空白候補でも繰り返しが停止する() {
		var stream: SourceStream
		= .init(.temporary(" x"))

		let count = stream.consume(
			trivia: [
				.token(Character.any("z").repeat(0...)),
				.space,
			]
		)
		#expect(count == 1)

		#expect(stream.offset == 1)
		#expect(stream.consume(trivia: []) == 0)
		#expect(stream.scan(grammar: nil, label: .none, trivia: [.space]) == nil)
		#expect(stream.offset == 1)
	}

	@Test
	func scanNextはUnicodeScalarを読みUTF8バイト数だけ進む() {
		let text: String
		= "日🙂e\u{0301}"
		var stream: SourceStream
		= .init(.temporary(text))
		var offset: Int = 0
		for scalar in text.unicodeScalars {
			#expect(stream.scanNext() == scalar)
			offset += scalar.utf8.count
			#expect(stream.offset == offset)
		}
		#expect(stream.isEnd)
		#expect(stream.scanNext() == nil)
	}

	@Test
	func 日本語コメントをUTF8範囲で読み飛ばす() {
		let prefix: String
		= " -- 日本語🙂e\u{0301}\r\n "
		var stream: SourceStream
		= .init(.temporary(prefix + "x"))
		let count = stream.consume(trivia: commentSpaces)
		#expect(count == prefix.utf8.count)
		#expect(stream.offset == prefix.utf8.count)
		#expect(stream.current == "x")
	}

	@Test(arguments: [("ς", "Σ"), ("K", "k"), ("k", "K"), ("日", "日")])
	func 大文字小文字を無視した一致も入力のUTF8バイト数だけ進む(
		input: String,
		pattern: String,
	) throws {
		var stream: SourceStream = .init(.temporary(input))
		let node = stream.scan(
			grammar: nil, label: .none,
			pattern: .string(pattern, caseInsensitive: true),
		)
		#expect(node?.string == input)
		#expect(node?.range == 0..<input.utf8.count)
		#expect(stream.offset == input.utf8.count)
		#expect(stream.isEnd)
	}
}


private var commentSpaces: [SpacePattern] {
	[
		.character(.any(" ", "\t", "\r", "\n")),
		.token(Sequence { "--"; Character.notNewline.repeat(0...) }),
	]
}
