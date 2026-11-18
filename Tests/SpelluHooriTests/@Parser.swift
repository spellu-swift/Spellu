import SpelluCore
import SpelluHoori


// API観点：Parser.initの文法検査、parseの照合・開始位置・木・状態分離、
// Generator.generateの単発解析を確認する。
@Suite struct HooriParserTests {

	@Test func 準備したモデルで異なる入力を繰り返し解析する() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment("a")
				Fragment("b")
			}
		}
		#expect(try parser.parse("a", strategy: .asis).root.string == "a")
		#expect(try parser.parse("b", strategy: .asis).root.string == "b")
		#expect(throws: SpelluError.self) {
			try parser.parse("c", strategy: .asis)
		}
		#expect(try parser.parse("a", strategy: .asis).root.string == "a")
	}

	@Test func 全体一致は後続に必要な短い反復候補を使う() throws {
		let parser: Parser = try makeParser {
			Repeat { Fragment(label: "body", "a") }
			Fragment(label: "tail", "a")
		}
		let tree: SourceNode = try parser.parse("aaa", strategy: .asis).root
		#expect(tree.parts.map(\.label) == ["body", "body", "tail"])
	}

	@Test func 前方一致はOptionalの本文を選ぶ() throws {
		let parser: Parser = try makeParser {
			Optional { Fragment(label: "body", "a") }
		}
		let tree: SourceNode = try parser.parse(
			"ab",
			method: .prefix,
			strategy: .asis
		).root
		#expect(tree.string == "a")
		#expect(tree.parts.map(\.label) == ["body"])
	}

	@Test func 左再帰の短い到達を呼び出し元へ返す() throws {
		let grammar: SpelluGrammar = .init(
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
			]
		)
		let parser: Parser = try .init(grammars: [grammar])
		let tree: SourceNode = try parser.parse("1+1+1", strategy: .asis).root
		#expect(tree.parts.map(\.string) == ["1+1", "+1"])
		let prefix: SourceNode = try parser.parse(
			"1+1",
			strategy: .asis,
			as: .rule("expr")
		).root
		#expect(prefix.parts.first?.label == "sum")
	}

	@Test func 同一到達の循環を打ち切る() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				RuleReference.rule("root")
				Fragment("a")
			}
		}
		#expect(try parser.parse("a", strategy: .asis).root.string == "a")
	}

	@Test func 空基底から間接左再帰を伸ばす() throws {
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
			]
		)
		let parser: Parser = try .init(grammars: [grammar])
		#expect(try parser.parse("yxyx", strategy: .asis).root.range == 0..<4)
	}

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

	@Test func Captureから戻ると記録を復元する() throws {
		let parser: Parser = try makeParser {
			Fragment(tag: "x", "a")
			Atomic { Fragment(tag: "x", "b") }
			Capture {
				Fragment(tag: "x", "c")
				Fragment(tag: "x")
			}
			Fragment(tag: "x").as(label: "restored")
		}
		let tree: SourceNode = try parser.parse("abccb", strategy: .asis).root
		#expect(tree.parts.last?.label == "restored")
		#expect(tree.parts.last?.string == "b")
		#expect(throws: SpelluError.self) {
			try parser.parse("abcca", strategy: .asis)
		}
	}

	@Test func 部分範囲と開始位置を絶対UTF8位置で扱う() throws {
		let parser: Parser = try makeParser { Fragment(label: "value", "あ") }
		let source: Source = .temporary("xxあ!", range: .utf8(2..<5))
		#expect(try parser.parse(source, strategy: .asis).root.range == 2..<5)
		#expect(throws: SpelluError.invalidStartOffset(3)) {
			try parser.parse(source, from: 3, strategy: .asis)
		}
		#expect(throws: SpelluError.invalidStartOffset(0)) {
			try parser.parse(source, from: 0, strategy: .asis)
		}
	}

	@Test func 重複文法と未定義ルールを準備時に拒否する() throws {
		let grammar: SpelluGrammar = makeGrammar { Fragment("a") }
		#expect(throws: SpelluError.duplicateGrammar(grammar: "S")) {
			try Parser(grammars: [grammar, grammar])
		}
		#expect(throws: SpelluError.ruleNotFound(grammar: "S", rule: "missing"))
		{ try makeParser { RuleReference.rule("missing") } }
	}

	@Test func compactでも一時字句を消費した範囲を保持する() throws {
		let parser: Parser = try makeParser {
			Fragment("a")
			Fragment("b")
		}
		let tree: SourceNode = try parser.parse("ab", strategy: .compact).root
		#expect(tree.range == 0..<2)
		#expect(tree.parts.isEmpty)
	}

	@Test func 正規等価でもScalar列が異なる字句のProgramを混同しない() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Fragment(label: "composed", "é")
				Fragment(label: "decomposed", "e\u{301}")
			}
		}
		let tree: SourceNode = try parser.parse("e\u{301}", strategy: .asis).root
		#expect(tree.parts.first?.label == "decomposed")
		#expect(tree.range == 0..<3)
	}

	@Test func 消費する反復を無消費反復の上限で打ち切らない() throws {
		let parser: Parser = try makeParser {
			Repeat(1024...1024) { Fragment("a") }
		}
		let tree: SourceNode = try parser.parse(
			.temporary(String(repeating: "a", count: 1024)),
			strategy: .compact
		).root
		#expect(tree.range == 0..<1024)
	}

}


private func makeGrammar(@SyntaxBuilder _ body: () -> [SyntaxIR])
	-> SpelluGrammar
{ .init(name: "S", spaces: [], trivia: [], rules: [("root", "root", true, Syntax(body))]) }

private func makeParser(@SyntaxBuilder _ body: () -> [SyntaxIR]) throws
	-> Parser
{ try .init(grammars: [makeGrammar(body)]) }
