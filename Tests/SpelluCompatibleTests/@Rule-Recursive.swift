// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行3件、一致3件、差異0件。
// ✅ 直接左再帰で左結合の木を作る：I=S=H 成功
// ✅ 同一文法の間接左再帰で両ルールの入れ子を保持する：I=S=H 成功
// ✅ 外部文法で左再帰した結果から親の後続を読む：I=S=H 成功
// 一覧ここまで

import Spellu


@Suite struct RuleRecursiveTests {

	@Test func 直接左再帰で左結合の木を作る() throws {
		let source: String = "1+2+3"
		let start: RuleReference = .init(grammar: "Expression", rule: "expr")
		let expected = Tree(label: "expr", source) {
			Tree(label: "sum", source) {
				Tree(label: "expr", "1+2") {
					Tree(label: "sum", "1+2") {
						Tree(label: "expr", "1") { Tree(label: "digit", "1") }
						Tree(label: "plus", "+")
						Tree(label: "digit", "2")
					}
				}
				Tree(label: "plus", "+")
				Tree(label: "digit", "3")
			}
		}

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			grammars: [expressionGrammar], startRule: start,
			source: source, match: source, asis: expected, compact: expected,
		)
	}

	@Test func 同一文法の間接左再帰で両ルールの入れ子を保持する() throws {
		let grammar: SpelluGrammar = .init(name: "Mutual", spaces: [], trivia: [], rules: [
			("A", "A", true, Syntax {
				ChoiceOf {
					Sequence(label: "extend") {
						RuleReference(grammar: nil, rule: "B")
						Fragment(label: "x", "x")
					}
					Fragment(label: "base", "a")
				}
			}),
			("B", "B", false, Syntax {
				RuleReference(grammar: nil, rule: "A")
				Fragment(label: "y", "y")
			}),
		])
		let source: String = "ayxyx"
		let expected = Tree(label: "A", source) {
			Tree(label: "extend", source) {
				Tree(label: "B", "ayxy") {
					Tree(label: "A", "ayx") {
						Tree(label: "extend", "ayx") {
							Tree(label: "B", "ay") {
								Tree(label: "A", "a") { Tree(label: "base", "a") }
								Tree(label: "y", "y")
							}
							Tree(label: "x", "x")
						}
					}
					Tree(label: "y", "y")
				}
				Tree(label: "x", "x")
			}
		}

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			grammars: [grammar],
			startRule: .init(grammar: "Mutual", rule: "A"),
			source: source,
			match: source,
			asis: expected,
			compact: expected,
		)
	}

	@Test func 外部文法で左再帰した結果から親の後続を読む() throws {
		let parent: SpelluGrammar = .init(name: "Parent", spaces: [], trivia: [], rules: [
			("root", "root", true, Syntax {
				RuleReference(grammar: "Expression", rule: "expr")
				Fragment(label: "end", "!")
			}),
		])
		let source: String = "1+2!"
		let expected = Tree(label: "root", source) {
			Tree(label: "expr", "1+2") {
				Tree(label: "sum", "1+2") {
					Tree(label: "expr", "1") { Tree(label: "digit", "1") }
					Tree(label: "plus", "+")
					Tree(label: "digit", "2")
				}
			}
			Tree(label: "end", "!")
		}

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			grammars: [expressionGrammar, parent],
			startRule: .init(grammar: "Parent", rule: "root"),
			source: source, match: source, asis: expected, compact: expected,
		)
	}

	private var expressionGrammar: SpelluGrammar {
		.init(name: "Expression", spaces: [], trivia: [], rules: [
			("expr", "expr", true, Syntax {
				ChoiceOf {
					Sequence(label: "sum") {
						RuleReference(grammar: nil, rule: "expr")
						Fragment(label: "plus", "+")
						Fragment(label: "digit") { ASCII.digit }
					}
					Fragment(label: "digit") { ASCII.digit }
				}
			}),
		])
	}

}
