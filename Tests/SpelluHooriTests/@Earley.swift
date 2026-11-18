import SpelluCore
import SpelluHoori

// Earley法で問題になりやすい文法と、エンジン固有の動作を確認する。
@Suite struct HooriEarleyTests {

	@Test func 空規則の完了が待ち登録より先でも項目が進む() throws {
		let parser: Parser = try makeParser {
			Optional { Fragment(label: "x", "a") }
			Optional { Fragment(label: "y", "b") }
			Fragment(label: "z", "c")
		}

		#expect(try parser.parse("c", strategy: .asis).root.parts.map(\.label) == ["z"])
		#expect(try parser.parse("bc", strategy: .asis).root.parts.map(\.label) == ["y", "z"])
		#expect(try parser.parse("abc", strategy: .asis).root.parts.map(\.label) == ["x", "y", "z"])
	}

	@Test func 空の規則を挟む隠れた左再帰を解析する() throws {
		let parser: Parser = try makeRules([
			("A", Syntax {
				ChoiceOf {
					Sequence {
						RuleReference.rule("B")
						RuleReference.rule("A")
						Fragment("x")
					}
					Fragment("y")
				}
			}),
			("B", Syntax {
				Optional { Fragment("z") }
			}),
		])

		#expect(try parser.parse("yxx", strategy: .asis).root.range == 0..<3)
		#expect(try parser.parse("zyx", strategy: .asis).root.range == 0..<3)
	}

	@Test func 基底のない循環は不一致になる() throws {
		let parser: Parser = try makeRules([
			("A", Syntax {
				RuleReference.rule("A")
				Fragment("x")
			}),
		])

		#expect(throws: SpelluError.self) {
			try parser.parse("x", strategy: .asis)
		}
	}

	@Test func 右再帰を解析する() throws {
		let parser: Parser = try makeRules([
			("A", Syntax {
				ChoiceOf {
					Sequence {
						Fragment("a")
						RuleReference.rule("A")
					}
					Fragment("a")
				}
			}),
		])

		#expect(try parser.parse("aaaa", strategy: .asis).root.range == 0..<4)
	}

	@Test func 終了位置が多いRepeatをv4の到達数の上限を超えて解析する() throws {
		let parser: Parser = try makeParser {
			Repeat { Fragment(label: "body", "a") }
		}
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: 5000)),
			strategy: .asis,
		).root

		#expect(tree.parts.count == 5000)
		#expect(tree.range == 0..<5000)
	}

	@Test func 同じ順位の別経路はambiguousPathになる() throws {
		let parser: Parser = try makeParser {
			AnyOf {
				Branch(.middle) { Fragment(label: "x", "a") }
				Branch(.middle) { Fragment(label: "y", "a") }
			}
		}

		#expect(throws: SpelluError.ambiguousPath(precedence: 50)) {
			try parser.parse("a", strategy: .asis)
		}
	}

	@Test func 同じ字句を別の位置で照合しても木はそれぞれのラベルになる() throws {
		let parser: Parser = try makeParser {
			Fragment(label: "first", "a")
			Fragment(label: "second", "a")
		}
		let tree: SourceNode = try parser.parse("aa", strategy: .asis).root

		#expect(tree.parts.map(\.label) == ["first", "second"])
		#expect(tree.parts.map(\.range) == [0..<1, 1..<2])
	}

	@Test func 字句Triviaは字句の範囲に含めない() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [.space],
			trivia: [],
			rules: [
				("root", "root", true, Syntax {
					Token(label: "a") { "a" }
					Token(label: "b") { "b" }
				}),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		let tree: SourceNode = try parser.parse(" a  b ", strategy: .asis).root

		#expect(tree.parts.map(\.range) == [1..<2, 4..<5])
		#expect(tree.range == 1..<5)
	}

	@Test func 別文法の公開ルールの候補を親の後続で絞る() throws {
		let inner: SpelluGrammar = .init(
			name: "I",
			spaces: [],
			trivia: [],
			rules: [
				("entry", "entry", true, Syntax {
					ChoiceOf {
						Fragment("a")
						Sequence {
							Fragment("a")
							Fragment("b")
						}
					}
				}),
			],
		)
		let outer: SpelluGrammar = .init(
			name: "O",
			spaces: [],
			trivia: [],
			rules: [
				("root", "root", true, Syntax {
					RuleReference.grammar("I", rule: "entry")
					Fragment("c")
				}),
			],
		)
		let parser: Parser = try .init(grammars: [outer, inner])

		#expect(try parser.parse("ac", strategy: .asis).root.range == 0..<2)
		let tree: SourceNode = try parser.parse("abc", strategy: .asis).root
		#expect(tree.parts.map(\.string) == ["ab", "c"])
		#expect(tree.parts.map(\.grammar) == ["I", "O"])
	}

	@Test func 同じ範囲の候補が多くても劣る候補を捨てて解析する() throws {
		let parser: Parser = try makeRules([
			("root", Syntax {
				Repeat { RuleReference.rule("item") }
			}),
			("item", Syntax {
				ChoiceOf {
					RuleReference.rule("x")
					RuleReference.rule("y")
				}
			}),
			("x", Syntax { Fragment("a") }),
			("y", Syntax { Fragment("a") }),
		])
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: 64)),
			strategy: .asis,
		).root

		#expect(tree.parts.count == 64)
		#expect(tree.parts.allSatisfy { $0.parts.first?.label == "x" })
	}

	@Test func 反復の前半が多通りでも先頭の回から比べて一つに絞る() throws {
		let parser: Parser = try makeParser {
			Repeat {
				ChoiceOf {
					Fragment(label: "one", "a")
					Fragment(label: "two", "aa")
				}
			}
		}
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: 40)),
			strategy: .asis,
		).root

		#expect(tree.parts.count == 40)
		#expect(tree.parts.allSatisfy { $0.label == "one" })
	}

	@Test func 比較不能な候補は親で決着しなければ曖昧になる() throws {
		let parser: Parser = try makeRules([
			("root", Syntax {
				Repeat { RuleReference.rule("item") }
			}),
			("item", Syntax {
				AnyOf {
					Branch(.middle) { Fragment(label: "x", "a") }
					Branch(.middle) { Fragment(label: "y", "a") }
				}
			}),
		])

		#expect(throws: SpelluError.ambiguousPath(precedence: 0)) {
			try parser.parse("aaa", strategy: .asis)
		}
	}

	@Test func 不一致の診断は最遠位置と期待値を返す() throws {
		let parser: Parser = try makeParser {
			Fragment("a")
			ChoiceOf {
				Fragment("b")
				Fragment("c")
			}
		}

		#expect {
			try parser.parse("ax", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 1 && expects == [.literal("b"), .literal("c")]
		}
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

private func makeRules(
	_ rules: [(String, Syntax)],
) throws -> Parser {
	try .init(
		grammars: [
			.init(
				name: "S",
				spaces: [],
				trivia: [],
				rules: rules.enumerated().map { index, rule in
					(rule.0, .labeled(rule.0), index == 0, rule.1)
				},
			),
		],
	)
}
