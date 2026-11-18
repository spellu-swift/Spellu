// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行2件、一致2件、差異0件。
// ✅ OptionalとChoiceOfを含むListの0要素を比較する：I=S=H 成功
// ✅ ListのChoiceOfの最遠失敗位置を保持する：I=S=H 不一致
// 一覧ここまで

import Spellu


// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct MixedTests {
	
	@Test
	func OptionalとChoiceOfを含むListの0要素を比較する() throws {
		let word: SyntaxIR = Token {
			ChoiceOf {
				Character.word
				Character.any("-")
			}
			.repeat(1...)
		}
		let rule = Syntax {
			"["
			List(0...) {
				Optional {
					word
					":"
				}
				ChoiceOf {
					word
				}
			} separator: {
				","
			}
			"]"
		}
		let source: String = "[]"
		
		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("[")
				Tree("]")
			},
			compact: Tree(label: "$", source),
		)
	}
	
	@Test func ListのChoiceOfの最遠失敗位置を保持する() throws {
		let rule = Syntax {
			"["
			List(0...) {
				ChoiceOf {
					"ab"
					"ac"
				}
			} separator: {
				","
			}
			"]"
		}
		let source: String = "[ax]"
		
		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("b"), .literal("c")],
			),
		)
	}
	
}
