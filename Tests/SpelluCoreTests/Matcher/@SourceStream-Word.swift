import SpelluCore
import SpelluLex


// 対象API: SourceStream.scan(grammar:label:wholePattern:words:caseInsensitive:)。
// 一致時の原文・UTF-8範囲・属性・消費位置、非ゼロ開始位置、空語、
// 語の不一致とパターンの不一致を確認する。
@Suite struct WordScanTests {

	@Test(arguments: ["if", "日本🙂", ""])
	func Wordは字句の範囲と属性を保持する(
		_ word: String,
	) throws {
		let source: Source = .temporary("前" + word + "後")
		var stream: SourceStream = .init(source)
		_ = stream.skip(count: 1)
		let begin: Int = stream.offset
		let pattern: TokenIR
		= word.isEmpty ? .sequence([]) : .string(word)

		let result: SourceNode? = stream.scan(
			grammar: "TestGrammar",
			label: "keyword",
			wholePattern: pattern,
			words: [word],
		)
		let node: SourceNode = try #require(result)

		#expect(node.range == begin..<(begin + word.utf8.count))
		#expect(node.string == word)
		#expect(node.substring == word)
		#expect(node.grammar == "TestGrammar")
		#expect(node.label == "keyword")
		#expect(node.source === source)
		#expect(node.parts.isEmpty)
		#expect(stream.offset == node.end)
		#expect(stream.current == "後")
	}

	@Test func Wordは字句全体が異なる語なら不一致になる() {
		var stream: SourceStream = .init(.temporary("iffy"))
		let node: SourceNode? = stream.scan(
			grammar: nil,
			label: "keyword",
			wholePattern: .string("iffy"),
			words: ["if"],
		)
		#expect(node == nil)
	}

	@Test func Wordはパターンの途中失敗で入力を消費しない() {
		var stream: SourceStream = .init(.temporary("ix"))
		let node: SourceNode? = stream.scan(
			grammar: nil,
			label: .none,
			wholePattern: .sequence([.string("i"), .string("f")]),
			words: ["if"],
		)
		#expect(node == nil)
		#expect(stream.offset == 0)
	}

	@Test(arguments: [
		("IF", true, true), ("IF", false, false),
		("else", false, true), ("while", true, false),
	])
	func 複数キーワードをフラグに応じて照合する(
		_ input: String,
		_ insensitive: Bool,
		_ matches: Bool,
	) throws {
		var stream: SourceStream = .init(.temporary("前" + input + "!"))
		_ = stream.skip(count: 1)
		let result: SourceNode? = stream.scan(
			grammar: nil,
			label: "keyword",
			wholePattern: .string(input),
			words: ["if", "else"],
			caseInsensitive: insensitive,
		)
		#expect((result != nil) == matches)
		if matches {
			let node: SourceNode = try #require(result)
			#expect(node.string == input)
			#expect(node.range == 3..<(3 + input.utf8.count))
			#expect(stream.offset == node.end)
		}
	}

	@Test(arguments: [false, true])
	func 空の語集合は空パターンでも一致しない(
		_ insensitive: Bool,
	) {
		var stream: SourceStream = .init(.temporary(""))
		let result: SourceNode? = stream.scan(
			grammar: nil, label: .none, wholePattern: .sequence([]),
			words: [], caseInsensitive: insensitive,
		)
		#expect(result == nil)
		#expect(stream.offset == 0)
	}

}
