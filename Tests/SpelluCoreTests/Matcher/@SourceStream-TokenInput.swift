@testable import SpelluCore
import SpelluLex


// 対象API: Source.asSubstring、SourceStream.cursor/offset(of:)/scan。
// 部分Sourceから手動で作ったTokenInputStreamをMatcherとVMに渡し、
// 原文上の位置、入力範囲、失敗時の復元と返却ノードの範囲を確認する。
@Suite struct SourceStreamTokenInputTests {

	@Test(arguments: [false, true])
	func 部分Sourceから作った入力の一致位置をMatcherとVMで原文位置に戻せる(
		_ optimized: Bool,
	) {
		let source: Source = .temporary("xKkb!", range: .character(1..<4))
		let stream: SourceStream = .init(source)
		let pattern: TokenIR = .sequence([
			"k".ignoresCase().repeat(0...), .string("kb"),
		])
		let compiler: TokenProgramCompiler = .init(
			optimizeSimpleRepetitions: optimized,
		)
		let tokenInput: TokenInputStream
		= .init(input: source.asSubstring, cursor: stream.cursor)
		var matcher: TokenMatcher = .init(
			stream: tokenInput, maxRepetition: stream.maxTokenRepetition,
		)
		var vm: TokenVM = .init(
			stream: tokenInput, maxRepetition: stream.maxTokenRepetition,
		)
		#expect(matcher.match(pattern) == .success(source.indexRange.upperBound))
		#expect(vm.match(compiler.compile(pattern))
			== .success(source.indexRange.upperBound))
		#expect(stream.offset(of: vm.stream.cursor) == source.range.upperBound)
		#expect(stream.offset(of: matcher.stream.cursor)
			== source.range.upperBound)
		#expect(stream.offset == source.range.lowerBound)
		#expect(vm.match(compiler.compile(.string("!")))
			== .failure(source.indexRange.upperBound))
		#expect(stream.offset(of: vm.stream.cursor) == source.range.upperBound)
	}

	@Test func 読み進めたSourceの位置を入力値と返却ノードへ維持する() throws {
		let source: Source = .temporary("xΣkb!", range: .utf8(1..<5))
		var stream: SourceStream = .init(source)
		#expect(stream.scanNext() == "Σ")
		let input: TokenInputStream
		= .init(input: source.asSubstring, cursor: stream.cursor)
		#expect(input.input == "Σkb")
		#expect(input.cursor == stream.cursor)
		var vm: TokenVM = .init(stream: input, maxRepetition: 1)
		#expect(vm.match(TokenProgramCompiler().compile(.string("kb")))
			== .success(source.indexRange.upperBound))
		#expect(stream.offset == 3)
		let node: SourceNode? = stream.scan(
			grammar: nil, label: "body", pattern: .string("kb"),
		)
		#expect(node?.string == "kb")
		#expect(node?.range == 3..<5)
		#expect(stream.offset == 5)
	}

	@Test func 字句全体の失敗では元のSource位置を保つ() {
		let source: Source = .temporary("xabc!", range: .character(1..<4))
		let stream: SourceStream = .init(source)
		let pattern: TokenIR = Sequence { "a".repeat(0...); "abc!" }
		let program: TokenProgram = TokenProgramCompiler().compile(pattern)
		let tokenInput: TokenInputStream
		= .init(input: source.asSubstring, cursor: stream.cursor)
		var matcher: TokenMatcher = .init(
			stream: tokenInput, maxRepetition: stream.maxTokenRepetition,
		)
		var vm: TokenVM = .init(
			stream: tokenInput, maxRepetition: stream.maxTokenRepetition,
		)
		#expect(matcher.match(pattern) == .failure(source.indexRange.upperBound))
		#expect(vm.match(program) == .failure(source.indexRange.upperBound))
		#expect(stream.offset(of: matcher.stream.cursor) == 1)
		#expect(stream.offset(of: vm.stream.cursor) == 1)
		#expect(stream.offset == 1)
	}

}
