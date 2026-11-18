@testable import SpelluCore
import SpelluLex


// 対象API: Expect.eos、trivia、
// 固定名、空文字、字句全体を確認する。
@Suite struct ExpectTests {

	@Test func 固定名は既存の種類と表記を維持する() {
		#expect(Expect.eos == .eos)
		#expect(Expect.trivia == .special("TRIVIA"))
	}

	@Test func 字句からは複数の文字とリテラルだけを生成する() {
		#expect(TokenIR.string("猫").expects
			== [Expect.literal("猫")])
		#expect(TokenIR.sequence([]).expects == [])
		#expect(TokenIR.alternative([
			.string("a"), .string("b"), .string("a"),
			.character(.include(.space)),
		]).expects
			== [.literal("a"), .literal("b"), .character("SPACE")])
		#expect("a".repeat(1..., behavior: .reluctant).expects
			== [.literal("a")]
		)
	}

}
