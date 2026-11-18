import SpelluCore
import SpelluHoori


// Parser.parseが返す本文の範囲と、自動Triviaの位置・所属・順序を確認する。
@Suite struct HooriAutomaticTriviaTests {

	@Test(arguments: [TreeStrategy.asis, .compact])
	func 前方一致と全体一致で実際に読んだ範囲を返す(
		strategy: TreeStrategy,
	) throws {
		let parser: Parser = try .init(grammars: [grammar(comment: "#") {
			Token(label: "A", "a")
			Token(label: "B", "b")
		}])
		let source: Source = .temporary(" # a # b # ")
		let prefix: SourceTree = try parser.parse(
			source,
			method: .prefix,
			strategy: strategy
		)
		let whole: SourceTree = try parser.parse(source, strategy: strategy)

		#expect(prefix.root.range == 3..<8)
		#expect(prefix.root.parts.map(\.label) == ["A", "B"])
		#expect(whole.root == prefix.root)
		let expected: [SourceNode] = [1..<2, 5..<6, 9..<10].map { range in
			.init(
				grammar: "S",
				label: "#trivia",
				source: source,
				begin: range.lowerBound,
				end: range.upperBound
			)
		}
		#expect(prefix.trivia == Array(expected.prefix(2)))
		#expect(whole.trivia == expected)
	}

	@Test func 部分範囲の開始位置から構文Triviaの絶対UTF8範囲を返す() throws {
		let parser: Parser = try .init(grammars: [grammar(spaces: [], comment: "　") { Token("値") }])
		let source: Source = .temporary("外前　値　後", range: .utf8(3..<15))
		let tree: SourceTree = try parser.parse(source, from: 6, strategy: .asis)

		#expect(tree.root.range == 9..<12)
		#expect(tree.trivia.map(\.range) == [6..<9, 12..<15])
		#expect(tree.trivia.map(\.string) == ["　", "　"])
		#expect(tree.trivia.allSatisfy { $0.source == source })
	}

	@Test func 連続する構文Triviaの範囲をまとめる() throws {
		let parser: Parser = try .init(grammars: [
			grammar(spaces: [], comment: "#") { Token("a") },
		])
		let tree: SourceTree = try parser.parse("##a#", strategy: .asis)

		#expect(tree.root.range == 2..<3)
		#expect(tree.trivia.map(\.range) == [0..<2, 3..<4])
		#expect(try parser.parse("a", strategy: .asis).trivia.isEmpty)
	}

	@Test func 明示Triviaは本文に残し自動Triviaだけを別に返す() throws {
		let parser: Parser = try .init(grammars: [grammar(comment: "#") {
			Token("a")
			Trivia
			Fragment("b")
			Token("c")
		}])
		let tree: SourceTree = try parser.parse(" a # b # c ", strategy: .asis)

		#expect(tree.root.parts.filter { $0.label == "#spaces" }
			.map(\.range) == [2..<5])
		#expect(tree.trivia.map(\.range) == [7..<8])
	}

	@Test func 失敗した枝と順位で棄却した枝のTriviaを捨てる() throws {
		let parser: Parser = try .init(grammars: [grammar(comment: "#") {
			ChoiceOf {
				Sequence {
					Atomic { Token("a") }
					Fragment("!")
				}
				Sequence {
					Fragment(label: "selected", "#a")
					Token("b")
				}
				Sequence {
					Token("a")
					Token("b")
				}
			}
		}])
		let tree: SourceTree = try parser.parse("#a #b #", strategy: .asis)

		#expect(tree.root.range == 0..<5)
		#expect(tree.root.parts.first?.parts.first?.label == "selected")
		#expect(tree.trivia.map(\.range) == [3..<4, 6..<7])
	}

	@Test func 自動Triviaの有無で本文の曖昧性を変えない() throws {
		let parser: Parser = try .init(grammars: [grammar {
			AnyOf {
				Fragment(label: "first", " a")
				Token(label: "second", "a")
			}
		}])

		#expect(throws: SpelluError.ambiguousPath(precedence: 0)) {
			try parser.parse(" a", strategy: .asis)
		}
	}

	@Test func Atomicと別文法のTriviaを呼び出し位置に挿入する() throws {
		let parent: SpelluGrammar = grammar(comment: "#") {
			Token("a")
			Rule("Child", "root")
			Token("b")
		}
		let child: SpelluGrammar = grammar(
			"Child",
			spaces: [.newline],
			comment: "@",
		) {
			Atomic {
				Token("x")
				Token("y")
			}
		}
		let parser: Parser = try .init(grammars: [parent, child])
		let tree: SourceTree = try parser.parse(
			" # a\n@x\n@y # b # ",
			strategy: .compact,
		)

		#expect(tree.root.range == 3..<14)
		#expect(tree.trivia.map(\.grammar) == ["S", "Child", "Child", "S", "S"])
		#expect(tree.trivia.map(\.range) == [
			1..<2, 5..<6, 8..<9, 11..<12, 15..<16,
		])
	}

	@Test func 反復とListの値および区切りのTriviaを入力順に返す() throws {
		let parser: Parser = try .init(grammars: [grammar(comment: "#") {
			Repeat(2...2) { Token("a") }
			List(2...2, lastSeparator: .deny) {
				Token("b")
			} separator: {
				Token(",")
			}
		}])
		let tree: SourceTree = try parser.parse("#a#a#b#,#b#", strategy: .asis)

		#expect(tree.trivia.map(\.range) == [
			0..<1, 2..<3, 4..<5, 6..<7, 8..<9, 10..<11,
		])
	}

	@Test func 多数のTriviaを持つ反復でも順序を保つ() throws {
		let count: Int = 1024
		let parser: Parser = try .init(grammars: [grammar(comment: "#") {
			Repeat(count...count) { Token("a") }
		}])
		let source: Source = .temporary(String(repeating: "#a", count: count))
		let tree: SourceTree = try parser.parse(source, strategy: .compact)
		let expected: [Range<Int>] = (0..<count).map { (2 * $0)..<(2 * $0 + 1) }

		#expect(tree.root.range == 1..<(2 * count))
		#expect(tree.trivia.map(\.range) == expected)
	}

	@Test func 多数の候補が同じ前置Triviaを待っても既定上限で解析できる() throws {
		let count: Int = 700
		let parser: Parser = try .init(grammars: [
			grammar(spaces: [], comment: "#") {
				ChoiceOf {
					for index: Int in 0..<count {
						Token(label: .labeled("branch\(index)"), "a")
					}
				}
			},
		])
		let tree: SourceTree = try parser.parse(
			.temporary(String(repeating: "#", count: count) + "a"),
			strategy: .compact,
		)

		#expect(tree.root.parts.map(\.label) == ["branch0"])
		#expect(tree.trivia.map(\.range) == [0..<count])
	}

//	@Test func 後方参照と本文中のEOSの前でもTriviaを収集する() throws {
//		let parser: Parser = try .init(grammars: [grammar {
//			Token(tag: "x", "a")
//			Token(tag: "x")
//			SyntaxIR._eos
//		}])
//		let tree: SourceTree = try parser.parse(
//			" a a ",
//			method: .prefix,
//			strategy: .asis,
//		)
//
//		#expect(tree.root.range == 1..<4)
//		#expect(tree.trivia.map(\.range) == [0..<1, 2..<3, 4..<5])
//	}

}


private func grammar(
	_ name: String = "S",
	spaces: [SpacePattern] = [.space],
	comment: String? = nil,
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SpelluGrammar {
	let rules: [(name: String, label: Label, expose: Bool, syntax: Syntax)]
	= [("root", "root", true, Syntax(body))]
	let triviaRules = comment.map { value in
		[("comment", Label.none, false, Syntax { Fragment(value) })]
	}
	return .init(
		name: name,
		spaces: spaces,
		trivia: comment == nil ? [] : ["comment"],
		rules: rules + (triviaRules ?? [])
	)
}
