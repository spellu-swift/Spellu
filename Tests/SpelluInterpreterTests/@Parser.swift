import SpelluCore
@testable import SpelluInterpreter


// API観点：
// - Parser.init：文法の検査、参照の解決。
// - Parser.parse：全体一致・前方一致、開始位置、開始ルール、asis/compactの木、
//   不一致の診断、作業量の上限、同じParserの使い回し。
// 構文ごとの意味は、それぞれのテスト（@Choice・@Repetition・@Tags・@Trivia・@Boundary）に置く。
@Suite struct InterpreterParserTests {

	// MARK: 文法の準備

	@Test func 重複した文法を準備時に拒否する() throws {
		let grammar: SpelluGrammar = makeGrammar { Fragment("a") }
		#expect(throws: SpelluError.duplicateGrammar(grammar: "S")) {
			try Parser(grammars: [grammar, grammar])
		}
	}

	@Test func 公開ルールのない文法を準備時に拒否する() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [("root", "root", false, Syntax { Fragment("a") })],
		)
		#expect(throws: SpelluError.noExposedRule(grammar: "S")) {
			try Parser(grammars: [grammar])
		}
	}

	@Test func 未定義の文法とルールの参照を準備時に拒否する() throws {
		#expect(throws: SpelluError.ruleNotFound(grammar: "S", rule: "missing")) {
			try makeParser { RuleReference.rule("missing") }
		}
		#expect(throws: SpelluError.grammarNotFound(grammar: "X")) {
			try makeParser { RuleReference.grammar("X", rule: "root") }
		}
	}

	@Test func 別の文法の非公開ルールの参照を準備時に拒否する() throws {
		let other: SpelluGrammar = .init(
			name: "T",
			spaces: [],
			trivia: [],
			rules: [
				("entry", "entry", true, Syntax { Fragment("a") }),
				("hidden", "hidden", false, Syntax { Fragment("b") }),
			],
		)
		let grammar: SpelluGrammar = makeGrammar {
			RuleReference.grammar("T", rule: "hidden")
		}
		#expect(throws: SpelluError.ruleNotFound(grammar: "T", rule: "hidden")) {
			try Parser(grammars: [grammar, other])
		}
	}

	// MARK: 木

	@Test func 全体一致で字句とSequenceとルールの木を作る() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				(
					"root", .none, true,
					Syntax {
						Fragment(label: "A", "a")
						Fragment("b")
						Sequence {
							Fragment(label: "C", "c")
						}
						RuleReference.rule("tail")
					}
				),
				(
					"tail", "T", false,
					Syntax {
						Sequence(label: "pair") {
							Fragment("d")
							Fragment(label: "E", "e")
						}
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])

		let asis: SourceNode = try parser.parse("abcde", strategy: .asis).root
		#expect(asis.asTreeTuple == Tree(label: "root", "abcde") {
			Tree(label: "A", "a")
			Tree("b")
			Tree(label: "#and", "c") {
				Tree(label: "C", "c")
			}
			Tree(label: "T", "de") {
				Tree(label: "pair", "de") {
					Tree("d")
					Tree(label: "E", "e")
				}
			}
		})
		#expect(asis.grammar == "S")

		let compact: SourceNode = try parser.parse("abcde", strategy: .compact).root
		#expect(compact.asTreeTuple == Tree(label: "root", "abcde") {
			Tree(label: "A", "a")
			Tree(label: "C", "c")
			Tree(label: "T", "de") {
				Tree(label: "pair", "de") {
					Tree(label: "E", "e")
				}
			}
		})
	}

	@Test func compactでも一時字句を読んだ範囲を保つ() throws {
		let parser: Parser = try makeParser {
			Fragment("a")
			Fragment("b")
		}
		let tree: SourceNode = try parser.parse("ab", strategy: .compact).root
		#expect(tree.range == 0..<2)
		#expect(tree.parts.isEmpty)
	}

	// MARK: 照合

	@Test func 前方一致は入力の残りを読まない() throws {
		let parser: Parser = try makeParser { Fragment(label: "A", "a") }
		let tree: SourceNode = try parser.parse(
			"ab",
			method: .prefix,
			strategy: .asis,
		).root
		#expect(tree.range == 0..<1)
		#expect(tree.parts.map(\.label) == ["A"])
	}

	@Test func 全体一致は入力の残りを不一致にする() throws {
		let parser: Parser = try makeParser { Fragment("a") }
		#expect {
			try parser.parse("ab", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 1 && expects == [.eos]
		}
	}

	@Test func 字句の不一致は最遠位置と期待値を返す() throws {
		let parser: Parser = try makeParser {
			Fragment("a")
			Fragment("bc")
		}
		#expect {
			try parser.parse("ax", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, line, column, expects) = error
			else { return false }

			return offset == 1 && line == 1 && column == 2
				&& expects == [.literal("bc")]
		}
	}

	@Test func Wordは語の一覧にある字句だけを受け付ける() throws {
		let parser: Parser = try makeParser {
			Word(label: "keyword", "if", "do") { ASCII.word.repeat(1...) }
		}
		let tree: SourceNode = try parser.parse("do", strategy: .asis).root
		#expect(tree.parts.map(\.label) == ["keyword"])
		#expect {
			try parser.parse("dog", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 3 && expects == [.literal("do"), .literal("if")]
		}
	}

	@Test func 大小文字を無視するWordを受け付ける() throws {
		let parser: Parser = try makeParser {
			Word(label: "keyword", "if", caseInsensitive: true) {
				ASCII.word.repeat(1...)
			}
		}
		#expect(try parser.parse("IF", strategy: .asis).root.string == "IF")
	}

	// MARK: 開始位置と開始ルール

	@Test func 開始位置と部分範囲を絶対UTF8位置で扱う() throws {
		let parser: Parser = try makeParser { Fragment(label: "value", "あ") }
		let source: Source = .temporary("xxあ!", range: .utf8(2..<5))
		#expect(try parser.parse(source, strategy: .asis).root.range == 2..<5)
		#expect(throws: SpelluError.invalidStartOffset(3)) {
			try parser.parse(source, from: 3, strategy: .asis)
		}
		#expect(throws: SpelluError.invalidStartOffset(0)) {
			try parser.parse(source, from: 0, strategy: .asis)
		}
		let prefix: SourceNode = try parser.parse(
			.temporary("xxあ!"),
			from: 2,
			method: .prefix,
			strategy: .asis,
		).root
		#expect(prefix.range == 2..<5)
	}

	@Test func 開始ルールを指定して解析する() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				("root", "root", true, Syntax { Fragment("a") }),
				("other", "other", false, Syntax { Fragment(label: "B", "b") }),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		#expect(try parser.parse("a", strategy: .asis).root.label == "root")
		let other: SourceNode = try parser.parse(
			"b",
			strategy: .asis,
			as: .rule("other"),
		).root
		#expect(other.label == "other")
		#expect(other.parts.map(\.label) == ["B"])
		#expect(throws: SpelluError.ruleNotFound(grammar: "S", rule: "missing")) {
			try parser.parse("a", strategy: .asis, as: .rule("missing"))
		}
		#expect(throws: SpelluError.grammarNotFound(grammar: "X")) {
			try parser.parse(
				"a",
				strategy: .asis,
				as: .grammar("X", rule: "root"),
			)
		}
	}

	@Test func 同じParserで異なる入力を繰り返し解析する() throws {
		let parser: Parser = try makeParser {
			Fragment(label: "A", "a")
			Word(label: "W", "x", "y") { ASCII.word }
		}
		#expect(try parser.parse("ax", strategy: .asis).root.string == "ax")
		#expect(throws: SpelluError.self) {
			try parser.parse("az", strategy: .asis)
		}
		#expect(try parser.parse("ay", strategy: .asis).root.string == "ay")
	}

	// MARK: 再帰と上限

	@Test func 基底のない左再帰は止まって不一致になる() throws {
		let parser: Parser = try makeParser {
			RuleReference.rule("root")
			Fragment("a")
		}
		#expect(throws: SpelluError.self) {
			try parser.parse("aaa", strategy: .asis)
		}
	}

	@Test func 右再帰のルールを読む() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				("root", "root", true, Syntax { RuleReference.rule("a1") }),
				("a1", "a1", false, Syntax { Fragment("a"); RuleReference.rule("a2") }),
				("a2", "a2", false, Syntax { Fragment("a"); RuleReference.rule("a3") }),
				("a3", "a3", false, Syntax { Fragment("a") }),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		let tree: SourceNode = try parser.parse("aaa", strategy: .compact).root
		#expect(tree.asTreeTuple == Tree(label: "root", "aaa") {
			Tree(label: "a1", "aaa") {
				Tree(label: "a2", "aa") {
					Tree(label: "a3", "a")
				}
			}
		})
	}

	@Test func 作業量の上限で止まる() throws {
		let parser: Parser = try .init(
			grammars: [makeGrammar { Fragment("a"); Fragment("b") }],
			limits: .init(maxWork: 3),
		)
		#expect(throws: SpelluError.safetyStop(.other("Interpreter work limit exceeded (3)"))) {
			try parser.parse("ab", strategy: .asis)
		}
	}

	@Test func 負の上限は0として扱う() throws {
		let limits: Limits = .init(maxTokenRepetition: -1, maxWork: -1)
		#expect(limits.maxTokenRepetition == 0)
		#expect(limits.maxWork == 0)
		#expect(Limits.default.maxWork == Limits.DEFAULT_MAX_WORK)
		#expect(Limits.default.maxTokenRepetition == Limits.DEFAULT_MAX_TOKEN_REPETITION)
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
