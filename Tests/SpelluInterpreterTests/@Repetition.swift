import SpelluCore
@testable import SpelluInterpreter


// 観点：Optional・Repeat・List・Enclosureの候補の選び方。
// - Optionalは本文ありを本文なしより優先し、後続のために本文を省略できる。
// - Repeatはeagerが続けること、reluctantが終えることを優先し、後続のために回数を譲る。
// - 回数の範囲、空の本文の扱い、空の回の上限。
// - Listは要素と「区切り＋要素」の反復、末尾の区切りの許可。
// - Enclosureは開始・本文の反復・終了を読む。
// 期待値はCompatibleTestsとHooriのテストのv4・Sakuya・Hooriと同じ（Triviaのない入力にした）。
@Suite struct InterpreterRepetitionTests {

	// MARK: Optional

	@Test func Optionalは本文が読めれば本文を選ぶ() throws {
		let parser: Parser = try makeParser {
			Optional { Fragment(label: "body", "a") }
			Fragment(label: "tail", "b")
		}
		#expect(try parser.parse("ab", strategy: .asis).root.parts.map(\.label) == ["body", "tail"])
		#expect(try parser.parse("b", strategy: .asis).root.parts.map(\.label) == ["tail"])
	}

	@Test func 前方一致ではOptionalの本文を選ぶ() throws {
		let parser: Parser = try makeParser {
			Optional { Fragment(label: "body", "a") }
		}
		let tree: SourceNode = try parser.parse(
			"ab",
			method: .prefix,
			strategy: .asis,
		).root
		#expect(tree.string == "a")
		#expect(tree.parts.map(\.label) == ["body"])
	}

	@Test func 後続のためにOptionalの本文を省略する() throws {
		let parser: Parser = try makeParser {
			Optional { Fragment(label: "body", "a") }
			Fragment(label: "tail", "a")
		}
		#expect(try parser.parse("a", strategy: .asis).root.parts.map(\.label) == ["tail"])
	}

	@Test func Optional内の同順位の重複成功は曖昧性にする() throws {
		let parser: Parser = try makeParser {
			Optional {
				AnyOf {
					Fragment(label: "left", "a")
					Fragment(label: "right", "a")
				}
			}
		}
		#expect(throws: SpelluError.ambiguousPath(precedence: 0)) {
			try parser.parse("a", strategy: .asis).root
		}
	}

	// MARK: Repeat

	@Test func Repeatを0回から複数回まで繰り返す() throws {
		let parser: Parser = try makeParser {
			Repeat { Fragment(label: "A", "a") }
		}
		#expect(try parser.parse("", strategy: .asis).root.parts.isEmpty)
		#expect(try parser.parse("aaa", strategy: .asis).root.parts.map(\.label) == ["A", "A", "A"])
	}

	@Test func 全体一致では後続に必要な短い回数を使う() throws {
		let parser: Parser = try makeParser {
			Repeat { Fragment(label: "body", "a") }
			Fragment(label: "tail", "a")
		}
		let tree: SourceNode = try parser.parse("aaa", strategy: .asis).root
		#expect(tree.parts.map(\.label) == ["body", "body", "tail"])
	}

	@Test func 前方一致ではeagerは多い回数をreluctantは少ない回数を選ぶ() throws {
		let eager: Parser = try makeParser {
			Repeat(1..., behavior: .eager) { Fragment(label: "A", "a") }
		}
		let reluctant: Parser = try makeParser {
			Repeat(1..., behavior: .reluctant) { Fragment(label: "A", "a") }
		}
		#expect(try eager.parse("aaa", method: .prefix, strategy: .asis).root.range == 0..<3)
		#expect(try reluctant.parse("aaa", method: .prefix, strategy: .asis).root.range == 0..<1)
	}

	@Test func eagerとreluctantで二つのRepeatへの分配が変わる() throws {
		for behavior: SyntaxRepetitionBehavior in [.eager, .reluctant] {
			let parser: Parser = try makeParser {
				Sequence(label: "first") {
					Repeat(behavior: behavior) { Fragment("a") }
				}
				Sequence(label: "second") {
					Repeat { Fragment("a") }
				}
			}
			let tree: SourceNode = try parser.parse("aa", strategy: .compact).root
			let first: String = behavior == .eager ? "aa" : ""
			let second: String = behavior == .eager ? "" : "aa"
			#expect(tree.asTreeTuple == Tree(label: "root", "aa") {
				Tree(label: "first", first)
				Tree(label: "second", second)
			})
		}
	}

	@Test func 回数の範囲の外は一致しない() throws {
		let parser: Parser = try makeParser {
			Repeat(2...3) { Fragment(label: "A", "a") }
		}
		#expect(throws: SpelluError.self) {
			try parser.parse("a", strategy: .asis).root
		}
		#expect(try parser.parse("aa", strategy: .asis).root.parts.count == 2)
		#expect(try parser.parse("aaa", strategy: .asis).root.parts.count == 3)
		#expect(throws: SpelluError.self) {
			try parser.parse("aaaa", strategy: .asis).root
		}
		#expect(try parser.parse("aaaa", method: .prefix, strategy: .asis).root.range == 0..<3)
	}

	@Test func 反復ごとにAnyOfの候補を選ぶ() throws {
		let parser: Parser = try makeParser {
			Repeat(2...2) {
				AnyOf {
					Branch(.high) {
						Fragment(label: "A", "a")
					}
					Branch(.low) {
						Fragment(label: "B", "b")
					}
				}
			}
		}
		#expect(try parser.parse("ab", strategy: .asis).root.parts.map(\.label) == ["A", "B"])
	}

	@Test func 空の本文は必須回数まで繰り返して終える() throws {
		let parser: Parser = try makeParser {
			Repeat(3...3) {
				Optional { Fragment(label: "A", "a") }
			}
		}
		#expect(try parser.parse("", strategy: .asis).root.range == 0..<0)
		#expect(try parser.parse("aa", strategy: .asis).root.parts.map(\.label) == ["A", "A"])
	}

	@Test func 必須回数に届くまでの空の回の上限で止める() throws {
		let parser: Parser = try .init(
			grammars: [
				makeGrammar {
					Repeat(3...3) {
						Optional { Fragment("a") }
					}
				},
			],
			limits: .init(maxEmptyRepetition: 1),
		)
		#expect(throws: SpelluError.safetyStop(.overLimitsOfRepetition(limits: 1))) {
			try parser.parse("", strategy: .asis).root
		}
	}

	@Test func 入力を読む回は空の回の上限で止めない() throws {
		let parser: Parser = try makeParser {
			Repeat(1024...1024) { Fragment("a") }
		}
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: 1024)),
			strategy: .compact,
		).root
		#expect(tree.range == 0..<1024)
	}

	@Test func 長い反復でも落ちない() throws {
		let count: Int = 10_000
		let parser: Parser = try makeParser {
			Repeat { Fragment(label: "A", "a") }
		}
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: count)),
			strategy: .compact,
		).root
		#expect(tree.parts.count == count)
	}

	// MARK: List

	@Test func Listは区切りを挟んで要素を並べる() throws {
		let parser: Parser = try makeParser {
			List(lastSeparator: .deny) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}
		#expect(try parser.parse("", strategy: .asis).root.parts.isEmpty)
		#expect(try parser.parse("a,a", strategy: .asis).root.asTreeTuple == Tree(label: "root", "a,a") {
			Tree(label: "A", "a")
			Tree(",")
			Tree(label: "A", "a")
		})
		#expect(throws: SpelluError.self) {
			try parser.parse("a,a,", strategy: .asis).root
		}
	}

	@Test func 末尾の区切りを許すListは区切りで終われる() throws {
		let parser: Parser = try makeParser {
			List(lastSeparator: .allow) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(label: "S", ",")
			}
		}
		let tree: SourceNode = try parser.parse("a,a,", strategy: .compact).root
		#expect(tree.parts.map(\.label) == ["A", "S", "A", "S"])
	}

	@Test func Listの回数の範囲は要素の数で数える() throws {
		let parser: Parser = try makeParser {
			List(2...3) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}
		#expect(throws: SpelluError.self) {
			try parser.parse("a", strategy: .asis).root
		}
		#expect(try parser.parse("a,a,a", strategy: .compact).root.parts.count == 3)
		#expect(throws: SpelluError.self) {
			try parser.parse("a,a,a,a", strategy: .asis).root
		}
	}

	// MARK: Enclosure

	@Test func Enclosureは開始と本文の反復と終了を読む() throws {
		let parser: Parser = try makeParser {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}
		#expect(try parser.parse("[]", strategy: .asis).root.asTreeTuple == Tree(label: "root", "[]") {
			Tree(label: "#opener", "[")
			Tree(label: "#closer", "]")
		})
		#expect(try parser.parse("[aa]", strategy: .compact).root.asTreeTuple == Tree(label: "root", "[aa]") {
			Tree(label: "A", "a")
			Tree(label: "A", "a")
		})
	}

}


private func makeGrammar(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SpelluGrammar {
	.init(
		name: "S",
		spaces: [],
		trivia: [],
		rules: [("root", "root", true, Syntax(body))],
	)
}


private func makeParser(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) throws -> Parser {
	try .init(grammars: [makeGrammar(body)])
}
