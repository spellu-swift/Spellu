import SpelluCore
@testable import SpelluInterpreter


// 観点：ChoiceOf・AnyOfの候補の選び方。
// - ChoiceOfは宣言順、AnyOfは優先値で比べ、比較は出口でまとめて行う。
// - 後続が失敗した候補は選ばれず、別の候補で選び直す。
// - 入れ子の選択肢の順位は、外側の比較範囲で足し合わせる。
// - 同順位で別の木が残れば曖昧性にし、残った候補の最上位の順位を載せる。
// 期待値はCompatibleTestsのv4・Sakuya・Hooriと同じ（Triviaのない入力にした）。
@Suite struct InterpreterChoiceTests {

	@Test func ChoiceOfは同じ入力に一致する先の候補を選ぶ() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment(label: "A", "a")
				Fragment(label: "B", "a")
			}
		}
		let tree: SourceNode = try parser.parse("a", strategy: .asis).root
		#expect(tree.parts.map(\.label) == ["A"])
	}

	@Test func ChoiceOfの後の候補が一致する() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
				Fragment(label: "C", "c")
			}
		}
		#expect(try parser.parse("c", strategy: .asis).root.parts.map(\.label) == ["C"])
	}

	@Test func 全体一致では先の短い候補がEOSで失敗すると後の候補を選ぶ() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment(label: "short", "a")
				Fragment(label: "long", "ab")
			}
		}
		let tree: SourceNode = try parser.parse("ab", strategy: .asis).root
		#expect(tree.parts.map(\.label) == ["long"])
		#expect(tree.range == 0..<2)
	}

	@Test func 前方一致では先の短い候補を選ぶ() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment(label: "short", "a")
				Fragment(label: "long", "ab")
			}
		}
		let tree: SourceNode = try parser.parse(
			"ab",
			method: .prefix,
			strategy: .asis,
		).root
		#expect(tree.parts.map(\.label) == ["short"])
		#expect(tree.range == 0..<1)
	}

	@Test func 先の短い候補で後続が一致すればそれを選ぶ() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment(label: "short", "a")
				Fragment(label: "long", "ab")
			}
			Fragment(label: "tail", "b")
		}
		let tree: SourceNode = try parser.parse("ab", strategy: .asis).root
		#expect(tree.asTreeTuple == Tree(label: "root", "ab") {
			Tree(label: "short", "a")
			Tree(label: "tail", "b")
		})
	}

	@Test func 外側の後続が失敗すれば別の候補で選び直す() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment(label: "long", "ab")
				Fragment(label: "short", "a")
			}
			Fragment(label: "tail", "b")
		}
		let tree: SourceNode = try parser.parse("ab", strategy: .asis).root
		#expect(tree.parts.map(\.label) == ["short", "tail"])
	}

	@Test func 空のSequenceの枝を選んで後続を読む() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Sequence {
				}
				Fragment(label: "A", "a")
			}
			Fragment(label: "tail", "a")
		}
		#expect(try parser.parse("a", strategy: .asis).root.asTreeTuple == Tree(label: "root", "a") {
			Tree(label: "#and", "")
			Tree(label: "tail", "a")
		})
		#expect(try parser.parse("a", strategy: .compact).root.asTreeTuple == Tree(label: "root", "a") {
			Tree(label: "tail", "a")
		})
	}

	@Test func 枝のないChoiceOfは一致しない() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
			}
		}
		#expect {
			try parser.parse("a", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 0 && expects.isEmpty
		}
	}

	@Test func すべての枝が失敗すれば最遠位置の期待値をまとめる() throws {
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

	@Test func 入れ子のChoiceOfの枝を選ぶ() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				ChoiceOf {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
				Fragment(label: "C", "c")
			}
		}
		#expect(try parser.parse("b", strategy: .asis).root.parts.map(\.label) == ["B"])
		#expect(try parser.parse("c", strategy: .asis).root.parts.map(\.label) == ["C"])
	}

	@Test func 枝をラベル付きSequenceでまとめる() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Sequence(label: "P") {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
				Fragment(label: "C", "a")
			}
		}
		let tree: SourceNode = try parser.parse("ab", strategy: .compact).root
		#expect(tree.asTreeTuple == Tree(label: "root", "ab") {
			Tree(label: "P", "ab") {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			}
		})
	}

	// MARK: AnyOf

	@Test func AnyOfは優先値の高い候補を選ぶ() throws {
		let parser: Parser = try makeParser {
			AnyOf {
				Branch(.low) {
					Fragment(label: "low", "a")
				}
				Branch(.high) {
					Fragment(label: "high", "a")
				}
			}
		}
		#expect(try parser.parse("a", strategy: .asis).root.parts.map(\.label) == ["high"])
	}

	@Test func AnyOfの同順位の重複成功は曖昧性にする() throws {
		let parser: Parser = try makeParser {
			AnyOf {
				Fragment(label: "left", "a")
				Fragment(label: "right", "a")
			}
		}
		#expect(throws: SpelluError.ambiguousPath(precedence: 0)) {
			try parser.parse("a", strategy: .asis)
		}
	}

	@Test func AnyOfの最高順位の重複成功は最高順位を載せて曖昧性にする() throws {
		let parser: Parser = try makeParser {
			AnyOf {
				Branch(.low) {
					Fragment(label: "low", "a")
				}
				Branch(.high) {
					Fragment(label: "left", "a")
				}
				Branch(.high) {
					Fragment(label: "right", "a")
				}
			}
		}
		#expect(throws: SpelluError.ambiguousPath(precedence: 100)) {
			try parser.parse("a", strategy: .asis)
		}
	}

	@Test func AnyOfの低順位の重複より高順位の成功を選ぶ() throws {
		let parser: Parser = try makeParser {
			AnyOf {
				Branch(.low) {
					Fragment(label: "left", "a")
				}
				Branch(.low) {
					Fragment(label: "right", "a")
				}
				Branch(.high) {
					Fragment(label: "high", "a")
				}
			}
		}
		#expect(try parser.parse("a", strategy: .asis).root.parts.map(\.label) == ["high"])
	}

	@Test func 全体一致では一致長が異なる同順位の候補からEOSに届くものを選ぶ() throws {
		let parser: Parser = try makeParser {
			AnyOf {
				Branch(.middle) {
					Fragment(label: "short", "a")
				}
				Branch(.middle) {
					Fragment(label: "long", "ab")
				}
			}
		}
		let tree: SourceNode = try parser.parse("ab", strategy: .compact).root
		#expect(tree.asTreeTuple == Tree(label: "root", "ab") {
			Tree(label: "long", "ab")
		})
	}

	@Test func 入れ子のAnyOfの順位は外側の比較範囲で足し合わせる() throws {
		let parser: Parser = try makeParser {
			AnyOf {
				Branch(.low) {
					AnyOf {
						Branch(.high) {
							Fragment(label: "inner", "a")
						}
					}
				}
				Branch(.middle) {
					Fragment(label: "outer", "a")
				}
			}
		}
		#expect(try parser.parse("a", strategy: .asis).root.parts.map(\.label) == ["inner"])
	}

	@Test func 比較範囲を閉じたSequenceの中の順位は外側の順位と足さない() throws {
		// Sequenceの中の高い順位は、Sequenceの選択履歴に閉じる。
		// 外側では、Sequenceを含む枝（low）と含まない枝（middle）の順位だけを比べる。
		let parser: Parser = try makeParser {
			AnyOf {
				Branch(.low) {
					Sequence {
						AnyOf {
							Branch(.high) {
								Fragment(label: "inner", "a")
							}
						}
					}
				}
				Branch(.middle) {
					Fragment(label: "outer", "a")
				}
			}
		}
		#expect(try parser.parse("a", strategy: .asis).root.parts.map(\.label) == ["outer"])
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
