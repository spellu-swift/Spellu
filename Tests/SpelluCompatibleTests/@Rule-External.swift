// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。asisとcompactを比較する。
// 集計：実行5件、一致5件、差異0件。
// ✅ 外部Listの候補を親の全体一致で絞る：I=S=H 成功
// ✅ 親の後続で外部ルールの短い候補を使う：I=S=H 成功
// ✅ 外部ルールの複数の導出が親まで成立すると曖昧になる：I=S=H 曖昧
// ✅ Atomicで包んだ外部ルールの候補を親から選び直さない：I=S=H 不一致
// ✅ 別文法をまたぐ間接左再帰を伸ばす：I=S=H 成功
// 一覧ここまで

import Spellu


@Suite struct RuleExternalTests {

	private let engines: [Spellu.Engine] = [.interpreter, .sakuya, .hoori]
	private let start: RuleReference = .init(grammar: "Parent", rule: "parent")

	@Test func 外部Listの候補を親の全体一致で絞る() throws {
		let parent: SpelluGrammar = grammar("Parent", rule: "parent") {
			RuleReference(grammar: "Child", rule: "child")
		}
		let child: SpelluGrammar = grammar("Child", rule: "child") {
			List(lastSeparator: .allow) {
				Fragment(label: "element", "...")
			} separator: {
				Fragment(label: "separator", "/")
			}
		}
		let source: String = ".../..."
		let expected = Tree(label: "parent", source) {
			Tree(label: "child", source) {
				Tree(label: "element", "...")
				Tree(label: "separator", "/")
				Tree(label: "element", "...")
			}
		}

		try compatibleTest(
			engines, grammars: [parent, child], startRule: start,
			source: source, match: source, asis: expected, compact: expected,
		)
	}

	@Test(arguments: [true, false])
	func 親の後続で外部ルールの短い候補を使う(ordered: Bool) throws {
		let parent: SpelluGrammar = grammar("Parent", rule: "parent") {
			RuleReference(grammar: "Child", rule: "child")
			Fragment(label: "tail", "b")
		}
		let child: SpelluGrammar = grammar("Child", rule: "child") {
			if ordered {
				ChoiceOf {
					Fragment(label: "long", "ab")
					Fragment(label: "short", "a")
				}
			}
			else {
				AnyOf {
					Fragment(label: "long", "ab")
					Fragment(label: "short", "a")
				}
			}
		}
		let expected = Tree(label: "parent", "ab") {
			Tree(label: "child", "a") { Tree(label: "short", "a") }
			Tree(label: "tail", "b")
		}

		try compatibleTest(
			engines, grammars: [parent, child], startRule: start,
			source: "ab", match: "ab", asis: expected, compact: expected,
		)
	}

	@Test func 外部ルールの複数の導出が親まで成立すると曖昧になる() throws {
		let parent: SpelluGrammar = grammar("Parent", rule: "parent") {
			RuleReference(grammar: "Child", rule: "child")
			Fragment("b")
		}
		let child: SpelluGrammar = grammar("Child", rule: "child") {
			AnyOf {
				Fragment(label: "left", "a")
				Fragment(label: "right", "a")
			}
		}

		try compatibleTest(
			engines, grammars: [parent, child], startRule: start,
			source: "ab", error: .ambiguousPath(precedence: 0),
		)
	}

	@Test func Atomicで包んだ外部ルールの候補を親から選び直さない() throws {
		let parent: SpelluGrammar = grammar("Parent", rule: "parent") {
			Atomic { RuleReference(grammar: "Child", rule: "child") }
			Fragment("b")
		}
		let child: SpelluGrammar = grammar("Child", rule: "child") {
			ChoiceOf {
				Fragment("ab")
				Fragment("a")
			}
		}

		try compatibleTest(
			engines, grammars: [parent, child], startRule: start,
			source: "ab", error: .unexpected(
				source: .temporary("ab"), offset: 2, line: 1, column: 3,
				expects: [.literal("b")],
			),
		)
	}

	@Test func 別文法をまたぐ間接左再帰を伸ばす() throws {
		let parent: SpelluGrammar = grammar("Parent", rule: "parent") {
			ChoiceOf {
				Sequence(label: "extend") {
					RuleReference(grammar: "Child", rule: "child")
					Fragment(label: "x", "x")
				}
				Fragment(label: "base", "a")
			}
		}
		let child: SpelluGrammar = grammar("Child", rule: "child") {
			RuleReference(grammar: "Parent", rule: "parent")
			Fragment(label: "y", "y")
		}
		let source: String = "ayx"
		let expected = Tree(label: "parent", source) {
			Tree(label: "extend", source) {
				Tree(label: "child", "ay") {
					Tree(label: "parent", "a") { Tree(label: "base", "a") }
					Tree(label: "y", "y")
				}
				Tree(label: "x", "x")
			}
		}

		try compatibleTest(
			engines, grammars: [parent, child], startRule: start,
			source: source, match: source, asis: expected, compact: expected,
		)
	}

	private func grammar(
		_ name: String,
		rule: String,
		@SyntaxBuilder _ body: () -> [SyntaxIR],
	) -> SpelluGrammar {
		.init(name: name, spaces: [], trivia: [], rules: [
			(rule, .init(rule), true, Syntax(body)),
		])
	}

}
