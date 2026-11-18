import SpelluCore
@testable import SpelluInterpreter


// 観点：GLL法の呼び出しの表で、左再帰と導出の循環を特別な処理なしに扱う。
// - 直接・間接の左再帰、空の基底から伸びる左再帰。
// - 呼び出し元が後続を読むために、ルールの短い到達を使える。
// - 同じ到達へ戻る循環は、同じルール呼び出しの中で打ち切る。
// - 基底のない左再帰は、結果を作らずに止まる。
@Suite struct InterpreterLeftRecursionTests {

	@Test func 直接左再帰で左結合の木を作る() throws {
		let parser: Parser = try .init(grammars: [expressionGrammar()])
		let tree: SourceNode = try parser.parse(
			"1+1+1",
			strategy: .compact,
			as: .rule("expr"),
		).root
		#expect(tree.asTreeTuple == Tree(label: "expr", "1+1+1") {
			Tree(label: "sum", "1+1+1") {
				Tree(label: "expr", "1+1") {
					Tree(label: "sum", "1+1") {
						Tree(label: "expr", "1")
					}
				}
			}
		})
	}

	@Test func 呼び出し元は左再帰の短い到達を使って後続を読む() throws {
		let parser: Parser = try .init(grammars: [expressionGrammar()])
		let tree: SourceNode = try parser.parse("1+1+1", strategy: .asis).root
		#expect(tree.parts.map(\.string) == ["1+1", "+1"])
		let prefix: SourceNode = try parser.parse(
			"1+1",
			strategy: .asis,
			as: .rule("expr"),
		).root
		#expect(prefix.parts.first?.label == "sum")
	}

	@Test func 間接左再帰を伸ばす() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				(
					"A", "A", true,
					Syntax {
						ChoiceOf {
							Sequence {
								RuleReference.rule("B")
								Fragment(label: "x", "x")
							}
							Fragment(label: "a", "a")
						}
					}
				),
				(
					"B", "B", false,
					Syntax {
						RuleReference.rule("A")
						Fragment(label: "y", "y")
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		let tree: SourceNode = try parser.parse("ayxyx", strategy: .compact).root
		#expect(tree.asTreeTuple == Tree(label: "A", "ayxyx") {
			Tree(label: "B", "ayxy") {
				Tree(label: "A", "ayx") {
					Tree(label: "B", "ay") {
						Tree(label: "A", "a") {
							Tree(label: "a", "a")
						}
						Tree(label: "y", "y")
					}
					Tree(label: "x", "x")
				}
				Tree(label: "y", "y")
			}
			Tree(label: "x", "x")
		})
	}

	@Test func 空の基底から間接左再帰を伸ばす() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax {
						ChoiceOf {
							Sequence {
								RuleReference.rule("B")
								Fragment("x")
							}
							Sequence {}
						}
					}
				),
				(
					"B", "B", false,
					Syntax {
						RuleReference.rule("root")
						Fragment("y")
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		#expect(try parser.parse("yxyx", strategy: .asis).root.range == 0..<4)
		#expect(try parser.parse("", strategy: .asis).root.range == 0..<0)
	}

	@Test func 同じ到達へ戻る循環を打ち切って有限の導出を選ぶ() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				RuleReference.rule("root")
				Fragment(label: "a", "a")
			}
		}
		let tree: SourceNode = try parser.parse("a", strategy: .asis).root
		#expect(tree.asTreeTuple == Tree(label: "root", "a") {
			Tree(label: "a", "a")
		})
	}

	@Test func 基底のない循環は結果を作らずに止まる() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				RuleReference.rule("root")
				Sequence {
					RuleReference.rule("root")
					Fragment("a")
				}
			}
		}
		#expect(throws: SpelluError.self) {
			try parser.parse("aa", strategy: .asis)
		}
	}

	// 左再帰の結果は入れ子の木になるので、SourceNodeを作らずに選択までを確かめる。
	@Test func 長い左再帰を選択まで進めても落ちない() throws {
		let count: Int = 3_000
		let parser: Parser = try .init(grammars: [expressionGrammar()])
		let source: String = (["1"] + Array(repeating: "+1", count: count)).joined()
		var session: Session = .init(
			table: parser.table,
			source: .temporary(source),
			limits: .init(maxWork: 10_000_000),
			start: 0,
		)
		let match: Match = try session.parse(
			.whole(try parser.table.start(nil)),
			at: 0,
		)
		#expect(match.end == source.utf8.count)
	}

}


/// `root = expr "+1"`、`expr = sum(expr "+" "1") | "1"`。
private func expressionGrammar() -> SpelluGrammar {
	.init(
		name: "S",
		spaces: [],
		trivia: [],
		rules: [
			(
				"root", "root", true,
				Syntax {
					RuleReference.rule("expr")
					Fragment(label: "tail", "+1")
				}
			),
			(
				"expr", "expr", false,
				Syntax {
					ChoiceOf {
						Sequence(label: "sum") {
							RuleReference.rule("expr")
							Fragment("+")
							Fragment("1")
						}
						Fragment("1")
					}
				}
			),
		],
	)
}


private func makeParser(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) throws -> Parser {
	try .init(
		grammars: [
			.init(
				name: "S",
				spaces: [],
				trivia: [],
				rules: [("root", "root", true, Syntax(body))],
			),
		],
	)
}
