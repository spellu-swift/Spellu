// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行3件、一致3件、差異0件。
// ✅ 空のCaptureは構文木にノードを追加しない：I=S=H 成功
// ✅ 入れ子のCaptureを抜けるたびに外側のtagを復元する：I=S=H 成功
// ✅ 失敗したCaptureの記録を次の候補へ引き継がない：I=S=H 成功
// 一覧ここまで

import Spellu


@Suite struct SyntaxCaptureTests {

	static let engines: [Spellu.Engine] = [.interpreter, .sakuya, .hoori]

	@Test func 空のCaptureは構文木にノードを追加しない() throws {
		let rule: Syntax = .init {
			Capture {}
			Fragment(label: "value", "a")
			Capture {}
		}
		let tree: TreeTuple<Label, String> = Tree(label: "$", "a") {
			Tree(label: "value", "a")
		}

		try compatibleTest(
			Self.engines,
			rule: rule,
			source: "a",
			match: "a",
			asis: tree,
			compact: tree,
		)
	}

	@Test func 入れ子のCaptureを抜けるたびに外側のtagを復元する() throws {
		let rule: Syntax = .init {
			Fragment(label: "outer", tag: "x", "a")
			Capture {
				Fragment(tag: "x").as(label: "inherited")
				Fragment(label: "middle", tag: "x", "b")
				Capture {
					Fragment(label: "inner", tag: "x", "c")
					Fragment(tag: "x").as(label: "innerRef")
				}
				Fragment(tag: "x").as(label: "middleRef")
			}
			Fragment(tag: "x").as(label: "outerRef")
		}
		let source: String = "aabccba"
		let tree: TreeTuple<Label, String> = Tree(label: "$", source) {
			Tree(label: "outer", "a")
			Tree(label: "inherited", "a")
			Tree(label: "middle", "b")
			Tree(label: "inner", "c")
			Tree(label: "innerRef", "c")
			Tree(label: "middleRef", "b")
			Tree(label: "outerRef", "a")
		}

		try compatibleTest(
			Self.engines,
			rule: rule,
			source: source,
			match: source,
			asis: tree,
			compact: tree,
		)
	}

	@Test func 失敗したCaptureの記録を次の候補へ引き継がない() throws {
		let rule: Syntax = .init {
			Fragment(label: "outer", tag: "x", "a")
			ChoiceOf {
				Capture {
					Fragment(tag: "x", "b")
					Fragment("!")
				}
				Fragment(label: "fallback", "b")
			}
			Fragment(tag: "x").as(label: "outerRef")
		}
		let source: String = "aba"
		let tree: TreeTuple<Label, String> = Tree(label: "$", source) {
			Tree(label: "outer", "a")
			Tree(label: "fallback", "b")
			Tree(label: "outerRef", "a")
		}

		try compatibleTest(
			Self.engines,
			rule: rule,
			source: source,
			match: source,
			asis: tree,
			compact: tree,
		)
	}

}
