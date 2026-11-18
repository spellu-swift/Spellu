// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行1件、一致1件、差異0件。
// ✅ Literalで記号を含む文字列をそのまま読む：I=S=H 成功
// 一覧ここまで

import Spellu


// Literalに文字列リテラルとString型変数を渡す使用例。
@Suite struct TokenLiteralTests {

	@Test func Literalで記号を含む文字列をそのまま読む() throws {
		let text: String
		= "a+b"

		let rules = [
			Syntax {
				Token(label: "literal") {
					Literal("a+b")
				}
			},
			Syntax {
				Token(label: "literal") {
					Literal(text)
				}
			},
		]

		let source: String
		= "a+b"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree(label: "literal", "a+b")
				},
				compact: Tree(label: "$", source) {
					Tree(label: "literal", "a+b")
				},
			)
		}
	}

}
