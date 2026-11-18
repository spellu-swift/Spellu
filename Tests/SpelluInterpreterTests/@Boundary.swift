import SpelluCore
@testable import SpelluInterpreter


// 観点：子の確定範囲（Atomic・別の文法のルール）。
// - 子は本文の中だけで候補を一つに確定し、親から別の候補へ戻れない。
// - 子の本文に書いた後続は、子の候補の選択に使う。
// - 子の不一致は親の経路の不一致、子の曖昧性は全体へ伝わる。
// - 別の文法のルールは、その文法のノードとtagで読む。左再帰の結果から親の後続を読める。
// - 同じ入口・同じ位置への再入と、入れ子の深さの上限で止める。
// 期待値はCompatibleTests・SpelluTests・Hooriのテストのv4・Sakuya・Hooriと同じ。
@Suite struct InterpreterBoundaryTests {

	// MARK: Atomic

	@Test func Atomicの確定結果を外側から選び直さない() throws {
		let parser: Parser = try makeParser {
			Atomic {
				ChoiceOf {
					Fragment("a")
					Sequence {
						Fragment("a")
						Fragment("b")
					}
				}
			}
			Fragment("c")
		}
		#expect(throws: SpelluError.self) {
			try parser.parse("abc", strategy: .asis)
		}
	}

	@Test func Atomicの本文の後続は候補の選択に使う() throws {
		let parser: Parser = try makeParser {
			Atomic {
				ChoiceOf {
					Fragment(label: "A", "a")
					Fragment(label: "AB", "ab")
				}
				Fragment(label: "C", "c")
			}
		}
		let tree: SourceNode = try parser.parse("abc", strategy: .asis).root
		#expect(tree.asTreeTuple == Tree(label: "root", "abc") {
			Tree(label: "#atomic", "abc") {
				Tree(label: "AB", "ab") {
					Tree("a")
					Tree("b")
				}
				Tree(label: "C", "c")
			}
		})
		#expect(try parser.parse("abc", strategy: .compact).root.parts.map(\.label) == ["AB", "C"])
	}

	@Test func 子の不一致は親の別の候補へ進む() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Sequence {
					Atomic { Fragment("ab") }
					Fragment("c")
				}
				Fragment(label: "X", "abd")
			}
		}
		#expect(try parser.parse("abd", strategy: .compact).root.parts.map(\.label) == ["X"])
	}

	@Test func 子の曖昧性は全体へ伝わる() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Atomic {
					AnyOf {
						Fragment(label: "left", "a")
						Fragment(label: "right", "a")
					}
				}
				Fragment(label: "other", "a")
			}
		}
		#expect(throws: SpelluError.ambiguousPath(precedence: 0)) {
			try parser.parse("a", strategy: .asis)
		}
	}

	@Test func 同じ位置で同じAtomicへ戻ると止める() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				(
					"A", "A", true,
					Syntax {
						ChoiceOf {
							Atomic { RuleReference.rule("A") }
							Fragment("a")
						}
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		#expect(throws: SpelluError.safetyStop(.other("Recursive prefix match"))) {
			try parser.parse("a", strategy: .asis)
		}
	}

	@Test func 確定範囲の入れ子の深さの上限で止める() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				(
					"A", "A", true,
					Syntax {
						Fragment("a")
						Optional {
							Atomic { RuleReference.rule("A") }
						}
					}
				),
			],
		)
		let parser: Parser = try .init(
			grammars: [grammar],
			limits: .init(maxBoundaryDepth: 2),
		)
		#expect(try parser.parse("aa", strategy: .asis).root.range == 0..<2)
		#expect(throws: SpelluError.safetyStop(.overLimitsOfRecursion(limits: 2))) {
			try parser.parse("aaaa", strategy: .asis)
		}
	}

	@Test func 深く入れ子になったAtomicでも落ちない() throws {
		let count: Int = 500
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				(
					"A", "A", true,
					Syntax {
						Fragment("a")
						Optional {
							Atomic { RuleReference.rule("A") }
						}
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		// asisでは木が1,000段になり、SourceNodeの解放の深さが気になるのでcompactにする。
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: count)),
			strategy: .compact,
		).root
		#expect(tree.range == 0..<count)
	}

	// MARK: 別の文法のルール

	@Test func 別の文法のルールをその文法のノードで読む() throws {
		let outer: SpelluGrammar = .init(
			name: "Outer",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax {
						Fragment(label: "A", "a")
						RuleReference.grammar("Inner", rule: "body")
						Fragment(label: "C", "c")
					}
				),
			],
		)
		let inner: SpelluGrammar = .init(
			name: "Inner",
			spaces: [],
			trivia: [],
			rules: [
				("body", "body", true, Syntax { Fragment(label: "B", "b") }),
			],
		)
		let parser: Parser = try .init(grammars: [outer, inner])
		let tree: SourceNode = try parser.parse("abc", strategy: .compact).root
		#expect(tree.asTreeTuple == Tree(label: "root", "abc") {
			Tree(label: "A", "a")
			Tree(label: "body", "b") {
				Tree(label: "B", "b")
			}
			Tree(label: "C", "c")
		})
		#expect(tree.parts.map(\.grammar) == ["Outer", "Inner", "Outer"])
	}

	@Test func 別の文法で左再帰した結果から親の後続を読む() throws {
		let expression: SpelluGrammar = .init(
			name: "Expression",
			spaces: [],
			trivia: [],
			rules: [
				(
					"expr", "expr", true,
					Syntax {
						ChoiceOf {
							Sequence(label: "sum") {
								RuleReference(grammar: nil, rule: "expr")
								Fragment(label: "plus", "+")
								Fragment(label: "digit") { ASCII.digit }
							}
							Fragment(label: "digit") { ASCII.digit }
						}
					}
				),
			],
		)
		let parent: SpelluGrammar = .init(
			name: "Parent",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax {
						RuleReference(grammar: "Expression", rule: "expr")
						Fragment(label: "end", "!")
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [expression, parent])
		let tree: SourceNode = try parser.parse(
			"1+2!",
			strategy: .asis,
			as: .grammar("Parent", rule: "root"),
		).root
		#expect(tree.asTreeTuple == Tree(label: "root", "1+2!") {
			Tree(label: "expr", "1+2") {
				Tree(label: "sum", "1+2") {
					Tree(label: "expr", "1") { Tree(label: "digit", "1") }
					Tree(label: "plus", "+")
					Tree(label: "digit", "2")
				}
			}
			Tree(label: "end", "!")
		})
	}

	@Test func 別の文法の同名tagは互いを上書きしない() throws {
		let outer: SpelluGrammar = .init(
			name: "Outer",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax {
						Fragment(tag: "x", "a")
						Rule("Inner", "root")
						Fragment(tag: "x")
					}
				),
			],
		)
		let inner: SpelluGrammar = .init(
			name: "Inner",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax {
						Optional { Fragment(tag: "x") }
						Fragment(tag: "x", "b")
						Fragment(tag: "x")
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [outer, inner])
		#expect(try parser.parse("abba", strategy: .asis).root.string == "abba")
		#expect(throws: SpelluError.self) {
			try parser.parse("aabba", strategy: .asis)
		}
	}

	@Test func 文法間の無消費の循環を除いて基底を読む() throws {
		let outer: SpelluGrammar = .init(
			name: "Outer",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax {
						ChoiceOf {
							RuleReference.grammar("Inner", rule: "root")
							Fragment("a")
						}
					}
				),
			],
		)
		let inner: SpelluGrammar = .init(
			name: "Inner",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", "root", true,
					Syntax { RuleReference.grammar("Outer", rule: "root") }
				),
			],
		)
		let parser: Parser = try .init(grammars: [outer, inner])
		let tree: SourceNode = try parser.parse("a", strategy: .asis).root
		#expect(tree.asTreeTuple == Tree(label: "root", "a") { Tree("a") })
	}

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
