@testable import SpelluCore
import SpelluLex


// 対象API: SourceStream.matchのTokenIR・TokenProgram・文字列・triviaの各入口。
// 原文上の成功／失敗位置、部分範囲、途中位置、反復上限、無消費を確認する。
@Suite struct SourceStreamMatchTests {

	@Test(arguments: [TokenEngine.interpreter, .momojiri])
	func IR照合は部分Sourceの最遠位置を返しカーソルを変えない(
		engine: TokenEngine,
	) {
		let source: Source = .temporary("xΣab!", range: .utf8(1..<5))
		var stream: SourceStream = .init(source, engine: engine)
		let end: String.Index = source.indexRange.upperBound
		let mismatch: String.Index = source.content.utf8.index(
			source.content.startIndex, offsetBy: 4,
		)
		#expect(stream.match(.string("Σab")) == .success(end))
		#expect(stream.match(.string("Σab!")) == .failure(end))
		#expect(stream.match(.string("Σac")) == .failure(mismatch))
		#expect(stream.offset == 1)

		#expect(stream.scanNext() == "Σ")
		#expect(stream.match(.string("ab!")) == .failure(end))
		#expect(stream.match(.string("ab")) == .success(end))
		#expect(stream.offset == 3)
	}

	@Test(arguments: [false, true])
	func Program照合でも最遠位置と部分Sourceの終端を維持する(
		optimized: Bool,
	) {
		let source: Source = .temporary("xabc!", range: .utf8(1..<4))
		let stream: SourceStream = .init(source)
		let compiler: TokenProgramCompiler = .init(
			optimizeSimpleRepetitions: optimized,
		)
		let end: String.Index = source.indexRange.upperBound
		#expect(stream.match(compiler.compile(.string("abc!"))) == .failure(end))
		#expect(stream.match(compiler.compile(.string("abc"))) == .success(end))
		#expect(stream.offset == 1)
	}

	@Test func Interpreter用StreamではProgram照合が開始位置で失敗する() {
		let stream: SourceStream = .init("abc", engine: .interpreter)
		let program: TokenProgram = TokenProgramCompiler().compile(.string("abc"))
		#expect(stream.match(program) == .failure(stream.cursor))
		#expect(stream.offset == 0)
	}

	@Test(arguments: [TokenEngine.interpreter, .momojiri])
	func 文字列の失敗位置はcaseFold前の原文のIndexを返す(
		engine: TokenEngine,
	) {
		var stream: SourceStream = .init("KΣx", engine: engine)
		let mismatch: String.Index = stream.input.utf8.index(
			stream.input.startIndex, offsetBy: 5,
		)
		#expect(stream.match("kσy", caseInsensitive: true) == .failure(mismatch))
		#expect(stream.match("kσx", caseInsensitive: true)
			== .success(stream.input.endIndex))
		#expect(stream.offset == 0)
	}

	@Test(arguments: [TokenEngine.interpreter, .momojiri])
	func triviaは部分一致の最遠位置と無消費の失敗を返す(
		engine: TokenEngine,
	) {
		var stream: SourceStream = .init("abX", engine: engine)
		let mismatch: String.Index = stream.input.index(
			stream.input.startIndex, offsetBy: 2,
		)
		#expect(stream.match([.string("abc")]) == .failure(mismatch))
		#expect(stream.match([.space]) == .failure(stream.cursor))
		#expect(stream.match([SpacePattern]()) == .failure(stream.cursor))
		#expect(stream.match([.string("ab")]) == .success(mismatch))
		#expect(stream.offset == 0)
		#expect(stream.consume(trivia: [.string("abc")]) == 0)
		#expect(stream.offset == 0)
	}

	@Test(arguments: [TokenEngine.interpreter, .momojiri])
	func 反復上限で読めない場合も空成功の場合もenumで返す(
		engine: TokenEngine,
	) {
		let stream: SourceStream = .init(
			"a", engine: engine, maxTokenRepetition: 0,
		)
		#expect(stream.match(.string("a")) == .failure(stream.cursor))
		#expect(stream.match(.string("a", amount: .exactly(0)))
			== .success(stream.cursor))
		#expect(stream.offset == 0)
	}

}
