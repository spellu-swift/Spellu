import SpelluCore
@testable import SpelluInterpreter


// 観点：入力が長くても、文法の入れ子が深くても、Swiftの呼び出しを深くせずに解析を終える。
// 認識は作業キュー、候補と木の組み立ては Walk でたどるので、深さで落ちない。
@Suite struct InterpreterDepthTests {

	@Test func 長い連接を読んでも落ちない() throws {
		let count: Int = 20_000
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax {
						SyntaxIR.sequence(
							.none,
							Array(repeating: Fragment(label: "A", "a"), count: count),
						)
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: count)),
			strategy: .compact,
		).root
		#expect(tree.range == 0..<count)
		#expect(tree.parts.count == count)
	}

	// SourceNodeは解放が再帰的で、深く入れ子にした木を解放するとテストのスレッドで落ちる。
	// エンジンによらない性質なので、ここでは選択までを確かめ、木はストアの番号でたどる。
	@Test func 深く入れ子になったルールを選択まで進めても落ちない() throws {
		let depth: Int = 10_000
		var rules: [(name: String, label: Label, expose: Bool, syntax: Syntax)] = [
			("root", "root", true, Syntax { RuleReference.rule("r0") }),
		]
		for index: Int in 0..<depth {
			let next: String = "r\(index + 1)"
			rules.append(
				(
					"r\(index)", "r", false,
					index + 1 < depth
						? Syntax { Fragment("a"); RuleReference.rule(next) }
						: Syntax { Fragment("a") }
				),
			)
		}
		let grammar: SpelluGrammar = .init(name: "S", spaces: [], trivia: [], rules: rules)
		let parser: Parser = try .init(grammars: [grammar])
		var session: Session = .init(
			table: parser.table,
			source: .temporary(String(repeating: "a", count: depth)),
			limits: .default,
			start: 0,
		)
		let match: Match = try session.parse(
			.whole(try parser.table.start(nil)),
			at: 0,
		)
		#expect(match.end == depth)

		// 各ルールの枝は、字句の葉と次のルールの枝を持つ。
		var tree: TreeID = try #require(session.store.treeLists.first(match.trees))
		var levels: Int = 0
		while let next: TreeID = session.store.treeLists.last(session.store[tree].children),
			session.store[next].label == "r"
		{
			tree = next
			levels += 1
		}
		#expect(levels == depth)
	}

}
