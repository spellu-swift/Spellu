import SpelluCore
@testable import SpelluInterpreter


// API観点：CodeTableBuilder.build が振る番号（ルールの本文、子の命令列、
// Listの選択肢、字句）、ルール参照の解決（ruleref）、
// CodeTable.instruction(at:)・grammar(of:)・start(_:)・alternatives(of:)・canonical(_:)・
// token(at:)。
@Suite struct InterpreterCodeTableTests {

	@Test func ルールの本文に番号を振る() throws {
		let table: CodeTable = try makeTable {
			Fragment("a")
		}
		let rule: RuleID = try table.start(nil)
		#expect(table[rule].name == "root")
		#expect(table[rule].label == "root")
		#expect(table[table[rule].body].code.count == 1)
	}

	@Test func Sequenceの本文に番号を振る() throws {
		let table: CodeTable = try makeTable {
			Fragment("a")
			Sequence {
				Fragment("b")
				Fragment("c")
			}
		}
		let body: BlockID = table[try table.start(nil)].body
		let sequence: Location = .init(block: body, pc: 1)
		let children: [BlockID] = try #require(table.children[sequence])
		#expect(children.count == 1)
		#expect(table[children[0]].code.count == 2)
		#expect(table.grammar(of: sequence) == table[body].grammar)
		#expect(table.alternatives(of: .sequence(sequence)) == [
			.code(.init(block: children[0], pc: 0)),
		])
	}

	@Test func Listの選択肢で複製した命令を元の命令に対応させる() throws {
		let table: CodeTable = try makeTable {
			List(lastSeparator: .allow) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(label: "S", ",")
			}
		}
		let body: BlockID = table[try table.start(nil)].body
		let alternatives: [BlockID] = try #require(
			table.children[.init(block: body, pc: 0)],
		)
		// 空・「要素＋残り」・「要素＋残り＋区切り」。
		#expect(alternatives.count == 3)
		let head: BlockID = alternatives[1]
		let tail: BlockID = alternatives[2]
		let pair: BlockID = try #require(
			table.children[.init(block: head, pc: 1)]?.first,
		)

		// 元の命令はそのまま。
		#expect(table.canonical(.init(block: head, pc: 0)) == .init(block: head, pc: 0))
		#expect(table.canonical(.init(block: pair, pc: 0)) == .init(block: pair, pc: 0))
		// 残りの本文の要素は「要素＋残り」の要素に、末尾の区切りは残りの本文の区切りに対応する。
		#expect(table.canonical(.init(block: pair, pc: 1)) == .init(block: head, pc: 0))
		#expect(table.canonical(.init(block: tail, pc: 0)) == .init(block: head, pc: 0))
		#expect(table.canonical(.init(block: tail, pc: 1)) == .init(block: head, pc: 1))
		#expect(table.canonical(.init(block: tail, pc: 2)) == .init(block: pair, pc: 0))
	}

	@Test func 字句とWordに連番を振る() throws {
		let table: CodeTable = try makeTable {
			Fragment("a")
			Sequence {
				Fragment("b")
			}
			Word("x", "y") { ASCII.word }
		}
		let body: BlockID = table[try table.start(nil)].body
		let sequence: BlockID = try #require(
			table.children[.init(block: body, pc: 1)]?.first,
		)
		let numbers: Set<Int> = [
			try table.token(at: .init(block: body, pc: 0)).rawValue,
			try table.token(at: .init(block: sequence, pc: 0)).rawValue,
			try table.token(at: .init(block: body, pc: 2)).rawValue,
		]
		#expect(numbers == [0, 1, 2])
		#expect(table.tokens.count == 3)
		// 字句でない命令には番号がない。
		#expect(throws: SpelluError.self) {
			try table.token(at: .init(block: body, pc: 1))
		}
	}

	@Test func Listで複製した字句は元の字句の番号を使う() throws {
		let table: CodeTable = try makeTable {
			List(lastSeparator: .allow) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(label: "S", ",")
			}
		}
		let body: BlockID = table[try table.start(nil)].body
		let alternatives: [BlockID] = try #require(
			table.children[.init(block: body, pc: 0)],
		)
		let head: BlockID = alternatives[1]
		let tail: BlockID = alternatives[2]
		let pair: BlockID = try #require(
			table.children[.init(block: head, pc: 1)]?.first,
		)
		// 番号を持つのは元の要素と区切りだけ。
		#expect(table.tokens.count == 2)
		#expect(
			try table.token(at: table.canonical(.init(block: tail, pc: 0)))
				== table.token(at: .init(block: head, pc: 0)),
		)
		#expect(
			try table.token(at: table.canonical(.init(block: tail, pc: 2)))
				== table.token(at: .init(block: pair, pc: 0)),
		)
	}

	@Test func 命令列の終わりには命令がない() throws {
		let table: CodeTable = try makeTable {
			Fragment("a")
		}
		let body: BlockID = table[try table.start(nil)].body
		#expect(table.instruction(at: .init(block: body, pc: 0)) != nil)
		#expect(table.instruction(at: .init(block: body, pc: 1)) == nil)
	}

	@Test func ルール参照を解決する() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				("root", "root", true, Syntax { RuleReference.rule("item") }),
				("item", "I", false, Syntax { Fragment("a") }),
			],
		)
		var builder: CodeTableBuilder = .init()
		let table: CodeTable = try builder.build([grammar])
		let root: RuleID = try table.start(nil)
		let item: RuleID = try table.start(.rule("item"))
		#expect(table.references[.init(block: table[root].body, pc: 0)] == item)
		#expect(table[item].label == "I")
		#expect(table.alternatives(of: .rule(item)) == [
			.code(.init(block: table[item].body, pc: 0)),
		])
		#expect(table.alternatives(of: .whole(item)) == [.whole(item, .rule)])
	}

	@Test func 開始ルールを省略すると最初の文法の最初の公開ルールになる() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				("hidden", "hidden", false, Syntax { Fragment("a") }),
				("entry", "entry", true, Syntax { Fragment("b") }),
			],
		)
		var builder: CodeTableBuilder = .init()
		let table: CodeTable = try builder.build([grammar])
		#expect(table[try table.start(nil)].name == "entry")
		#expect(table[try table.start(.rule("hidden"))].name == "hidden")
	}

}


private func makeTable(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) throws -> CodeTable {
	var builder: CodeTableBuilder = .init()

	return try builder.build([
		.init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [("root", "root", true, Syntax(body))],
		),
	])
}
