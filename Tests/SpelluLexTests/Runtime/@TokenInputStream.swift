@testable import SpelluLex


// 対象API: init(input:cursor:)、input、cursor、scanNext、matchの全入口。
// 原文のIndex、途中位置、部分範囲、EOF、失敗時の位置、コピーと巻き戻しを確認する。
@Suite struct TokenInputStreamTests {

	@Test func 部分文字列と原文のIndexを保持する() {
		let original: String = "xΣb!"
		let lower: String.Index = original.unicodeScalars.index(
			after: original.startIndex,
		)
		let upper: String.Index = original.index(before: original.endIndex)
		let stream: TokenInputStream = .init(input: original[lower..<upper])
		#expect(stream.input == "Σb")
		#expect(stream.cursor == lower)
		#expect(stream.input.endIndex == upper)
		#expect(stream.offset == 1)
	}

	@Test func 指定した途中の位置から読み始める() {
		let original: String = "xΣb!"
		let lower: String.Index = original.index(after: original.startIndex)
		let upper: String.Index = original.index(before: original.endIndex)
		let middle: String.Index = original.unicodeScalars.index(after: lower)
		var stream: TokenInputStream = .init(
			input: original[lower..<upper], cursor: middle,
		)
		#expect(stream.cursor == middle)
		#expect(stream.scanNext() == "b")
		#expect(stream.cursor == upper)
		#expect(stream.scanNext() == nil)
		#expect(stream.cursor == upper)
	}

	@Test func 空の入力では空文字列だけが一致し読み取りは失敗する() {
		var stream: TokenInputStream = .init(input: ""[...])
		let start: String.Index = stream.cursor
		#expect(stream.scanNext() == nil)
		#expect(stream.match(string: "a", byteCount: 1) == .failure(start))
		#expect(stream.match(string: "", byteCount: 0) == .success(start))
		#expect(stream.cursor == start)
	}

	@Test func 文字列は範囲内で一括比較し失敗時に位置を変えない() {
		var stream: TokenInputStream = .init("x日本!", range: 1..<7)
		let start: String.Index = stream.cursor
		let middle: String.Index = stream.input.unicodeScalars.index(after: start)
		let end: String.Index = stream.input.endIndex
		#expect(stream.match(string: "日本!", byteCount: 7) == .failure(end))
		#expect(stream.match(string: "日語", byteCount: 6) == .failure(middle))
		#expect(stream.match(string: "", byteCount: 0) == .success(start))
		#expect(stream.cursor == start)
		#expect(stream.match(string: "日本", byteCount: 6) == .success(end))
		#expect(stream.offset == 7)
		#expect(stream.match(string: "!", byteCount: 1) == .failure(end))
		#expect(stream.scanNext() == nil)
		#expect(stream.offset == 7)
	}

	@Test func 結合文字をCharacterではなくScalar単位で読む() {
		var stream: TokenInputStream = .init("xe\u{301}!", range: 1..<4)
		let after: String.Index = stream.input.unicodeScalars.index(
			after: stream.cursor,
		)
		#expect(stream.match(string: "e", byteCount: 1)
			== .success(after))
		#expect(stream.scanNext() == "\u{301}")
		#expect(stream.offset == 4)
		#expect(stream.scanNext() == nil)
	}

	@Test func コピーと巻き戻しは別の入力位置に影響しない() {
		var original: TokenInputStream = .init("Σb")
		let saved: String.Index = original.cursor
		var copy: TokenInputStream = original
		#expect(copy.scanNext() == "Σ")
		#expect(original.cursor == saved)
		#expect(original.match(string: "Σb", byteCount: 3)
			== .success(original.input.endIndex))
		copy.cursor = saved
		#expect(copy.scanNext() == "Σ")
		#expect(original.offset == 3)
		#expect(copy.offset == 2)
	}

	@Test(arguments: [TokenEngine.interpreter, .momojiri])
	func IR照合は成功と最遠失敗を返し入力位置を変えない(
		engine: TokenEngine,
	) {
		let stream: TokenInputStream = .init("xabc!", range: 1..<4)
		let end: String.Index = stream.input.endIndex
		#expect(stream.match(.string("abc!"), engine: engine) == .failure(end))
		#expect(stream.match(.string("abc"), engine: engine) == .success(end))
		#expect(stream.match(.string("abc"), engine: engine,
			maxTokenRepetition: 0) == .failure(stream.cursor))
		#expect(stream.match(.string("", amount: .exactly(0)), engine: engine,
			maxTokenRepetition: 0) == .success(stream.cursor))
		#expect(stream.offset == 1)
	}

	@Test(arguments: [false, true])
	func Program照合は成功と最遠失敗を返し入力位置を変えない(
		optimized: Bool,
	) {
		let stream: TokenInputStream = .init("xabc!", range: 1..<4)
		let compiler: TokenProgramCompiler = .init(
			optimizeSimpleRepetitions: optimized,
		)
		let end: String.Index = stream.input.endIndex
		#expect(stream.match(compiler.compile(.string("abc!"))) == .failure(end))
		#expect(stream.match(compiler.compile(.string("abc"))) == .success(end))
		#expect(stream.match(compiler.compile(.string("abc")),
			maxTokenRepetition: 0) == .failure(stream.cursor))
		#expect(stream.match(compiler.compile([]),
			maxTokenRepetition: 0) == .success(stream.cursor))
		#expect(stream.offset == 1)
	}

}
