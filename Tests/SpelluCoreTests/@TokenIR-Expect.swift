@testable import SpelluCore
import SpelluLex


// 対象API: TokenIR.expectations(in:at:)、CharacterSet.expect。
// 最遠位置、分岐、反復、大小文字、原文範囲と重複排除を確認する。
@Suite struct TokenIRExpectTests {

	@Test func Sequenceの成功済み要素を除いて同位置の候補を列挙する() {
		let pattern: TokenIR = Sequence {
			"ab"
			ChoiceOf { "cd"; "ce"; "cd"; Character.space }
		}
		let stream: SourceStream = "abX"
		#expect(pattern.expectations(in: stream, at: position(2, in: stream))
			== [.literal("cd"), .literal("ce"), .character("SPACE")])
		#expect(stream.offset == 0)
	}

	@Test func 分岐の途中の一致が短い候補を最遠位置へ混ぜない() {
		let pattern: TokenIR = ChoiceOf { "ax"; "abcd"; "abce"; "abcd" }
		let stream: SourceStream = "abcX"
		#expect(pattern.expectations(in: stream, at: position(3, in: stream))
			== [.literal("d"), .literal("e")])
		#expect(pattern.expectations(in: stream, at: position(2, in: stream))
			== [])
	}

	@Test func 反復と大小文字の設定を文法の説明に変換しない() {
		let pattern: TokenIR = Sequence {
			"ab".ignoresCase().repeat(1...)
			ChoiceOf { "cd"; "ce" }
		}
		let stream: SourceStream = "ABabX"
		#expect(pattern.expectations(in: stream, at: position(4, in: stream))
			== [.literal("ab"), .literal("cd"), .literal("ce")])
	}

	@Test func 途中失敗した文字列はその要素の未消費部分を返す() {
		let stream: SourceStream = "abX"
		#expect(TokenIR.string("abcd").expectations(
			in: stream, at: position(2, in: stream),
		) == [.literal("cd")])

		let repeated: TokenIR = Sequence { "z"; "ab".repeat(2...) }
		let repetitionStream: SourceStream = "zabaX"
		#expect(repeated.expectations(
			in: repetitionStream, at: position(4, in: repetitionStream),
		) == [.literal("b")])
	}

	@Test(arguments: [
		("KX", "kbc", 3),
		("kX", "Kbc", 1),
		("e\u{301}X", "e\u{301}bc", 3),
	])
	func Unicodeの一致済みScalarを原文のバイト長に依存せず除く(
		_ source: String,
		_ literal: String,
		_ offset: Int,
	) {
		let stream: SourceStream = .init(.temporary(source))
		let pattern: TokenIR = literal.ignoresCase()
		#expect(pattern.expectations(in: stream, at: position(offset, in: stream))
			== [.literal("bc")])
	}


	@Test func 空の候補と反復上限では架空の期待値を作らない() {
		let stream: SourceStream = "X"
		#expect(TokenIR.alternative([]).expectations(
			in: stream, at: stream.cursor,
		) == [])
		#expect(TokenIR.string("a", amount: .exactly(0)).expectations(
			in: stream, at: stream.cursor,
		) == [])
		let limited: SourceStream = .init("X", maxTokenRepetition: 1)
		#expect(TokenIR.string("a", amount: .exactly(2)).expectations(
			in: limited, at: limited.cursor,
		) == [])
		#expect(TokenIR.string("").expectations(
			in: stream, at: stream.cursor,
		) == [])
	}

	@Test func Unicodeを含む部分Sourceの終端を越えて探索しない() {
		let source: Source = .temporary("前日本後", range: .utf8(3..<9))
		let stream: SourceStream = .init(source)
		let pattern: TokenIR = Sequence { "日"; ChoiceOf { "本a"; "本b" } }
		#expect(pattern.expectations(in: stream, at: position(9, in: stream))
			== [.literal("a"), .literal("b")])
	}

	@Test func 文字集合の和と反転と空集合を区別する() {
		#expect(CharacterSet.include(.space, .newline).expect
			== .character("SPACE | NEWLINE"))
		#expect(CharacterSet.exclude(.space, .newline).expect
			== .character("not(SPACE | NEWLINE)"))
		#expect(CharacterSet.include([]).expect == .character("EMPTY"))
		#expect(CharacterSet.exclude([]).expect == .character("ALL"))
	}

	private func position(
		_ offset: Int,
		in stream: SourceStream,
	) -> String.Index {
		stream.input.utf8.index(stream.input.startIndex, offsetBy: offset)
	}

}
