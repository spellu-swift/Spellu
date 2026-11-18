import SpelluCore
@testable import SpelluInterpreter


// 観点：自動Triviaと明示Trivia。
// - Token・Word・後方参照（spacious）・全体一致のEOSの前で、文法のTriviaを読む。
//   Fragment（spaciousでない字句）の前では読まない。
// - 字句Trivia（空白・改行・文字・文字列・TokenIR）と構文Triviaを組み合わせて読む。
// - 構文Triviaの中（Triviaの照合中）では、自動Triviaを挟まない。
// - 構文Triviaで記録したtagは後続から参照できる。
// - 明示Triviaは範囲全体を一つの葉（`#spaces`）にし、空なら期待値TRIVIAで失敗する。
// 期待値はCompatibleTestsとSpelluTestsのv4・Sakuya・Hooriと同じ。
@Suite struct InterpreterTriviaTests {

	// MARK: 自動Trivia

	@Test func Tokenの前の空白を自動で読む() throws {
		let parser: Parser = try makeParser(spaces: [.space]) {
			Token(label: "A", "a")
			Token(label: "B", "b")
		}
		let tree: SourceNode = try parser.parse(" a  b ", strategy: .asis).root
		#expect(tree.asTreeTuple == Tree(label: "root", "a  b") {
			Tree(label: "A", "a")
			Tree(label: "B", "b")
		})
		#expect(tree.parts.map(\.range) == [1..<2, 4..<5])
	}

	@Test func Fragmentの前では自動Triviaを読まない() throws {
		let parser: Parser = try makeParser(spaces: [.space]) {
			Fragment(label: "A", "a")
			Fragment(label: "B", "b")
		}
		#expect(try parser.parse("ab", strategy: .asis).root.parts.count == 2)
		#expect(throws: SpelluError.self) {
			try parser.parse("a b", strategy: .asis)
		}
	}

	@Test func 定義にない空白は読まない() throws {
		let parser: Parser = try makeParser(spaces: [.space]) {
			Token("a")
			Token("b")
		}
		#expect(throws: SpelluError.self) {
			try parser.parse("a\nb", strategy: .asis)
		}
	}

	@Test func 文字列と改行をTriviaとして交互に読む() throws {
		let parser: Parser = try makeParser(spaces: [.newline, .string("--")]) {
			Token(label: "A", "a")
			Token(label: "B", "b")
		}
		#expect(try parser.parse("a--\n--b", strategy: .compact).root.parts.map(\.label) == ["A", "B"])
	}

	@Test func 構文Triviaを字句Triviaと組み合わせて読む() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [.space],
			trivia: ["comment"],
			rules: [
				(
					"root", "root", true,
					Syntax {
						Token(label: "A", "a")
						Token(label: "B", "b")
					}
				),
				(
					"comment", "comment", false,
					Syntax {
						Fragment("/*")
						Fragment { "x".repeat(0...) }
						Fragment("*/")
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		let tree: SourceNode = try parser.parse("a /*xx*/ /**/b", strategy: .asis).root
		#expect(tree.asTreeTuple == Tree(label: "root", "a /*xx*/ /**/b") {
			Tree(label: "A", "a")
			Tree(label: "B", "b")
		})
	}

	@Test func 構文Triviaの中では自動Triviaを挟まない() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [.space],
			trivia: ["comment"],
			rules: [
				(
					"root", "root", true,
					Syntax {
						Token(label: "A", "a")
						Token(label: "B", "b")
					}
				),
				(
					"comment", "comment", false,
					Syntax {
						Token("[")
						Token("]")
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		#expect(try parser.parse("a []b", strategy: .asis).root.string == "a []b")
		#expect(throws: SpelluError.self) {
			try parser.parse("a [ ]b", strategy: .asis)
		}
	}

	@Test func 構文Triviaで記録したtagを後続から参照する() throws {
		let grammar: SpelluGrammar = .init(
			name: "G",
			spaces: [],
			trivia: ["comment"],
			rules: [
				(
					"root", "root", true,
					Syntax {
						Token(":")
						Fragment(tag: "x")
					}
				),
				(
					"comment", "comment", false,
					Syntax {
						Fragment("[")
						Fragment(tag: "x", "a")
						Fragment("]")
					}
				),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])
		#expect(try parser.parse("[a]:a", strategy: .asis).root.string == ":a")
	}

	@Test func 全体一致では末尾の空白を読んでからEOSを確かめる() throws {
		let parser: Parser = try makeParser(spaces: [.space]) {
			Token(label: "A", "a")
		}
		let tree: SourceNode = try parser.parse("a  ", strategy: .asis).root
		#expect(tree.range == 0..<1)
		#expect {
			try parser.parse("a  b", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 3 && expects == [.eos]
		}
	}

	// MARK: 明示Trivia

	@Test func 明示Triviaは範囲全体を一つの葉にする() throws {
		let parser: Parser = try makeParser(spaces: [.space]) {
			Token(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}
		#expect(try parser.parse(" a b", strategy: .asis).root.asTreeTuple == Tree(label: "root", "a b") {
			Tree(label: "A", "a")
			Tree(label: "#spaces", " ")
			Tree(label: "B", "b")
		})
		#expect(try parser.parse(" a b", strategy: .compact).root.asTreeTuple == Tree(label: "root", "a b") {
			Tree(label: "A", "a")
			Tree(label: "B", "b")
		})
	}

	@Test func 明示Triviaが空なら期待値TRIVIAで失敗する() throws {
		let parser: Parser = try makeParser(spaces: [.space]) {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}
		#expect {
			try parser.parse("ab", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 1 && expects == [.trivia]
		}
		#expect {
			try parser.parse("", strategy: .asis)
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 0 && expects == [.literal("a")]
		}
	}

	@Test func 明示Triviaのラベルを付け直す() throws {
		let parser: Parser = try makeParser(spaces: [.space]) {
			Fragment(label: "A", "a")
			SyntaxIR.trivia.as(label: "space")
			Fragment(label: "B", "b")
		}
		#expect(try parser.parse("a b", strategy: .compact).root.asTreeTuple == Tree(label: "root", "a b") {
			Tree(label: "A", "a")
			Tree(label: "space", " ")
			Tree(label: "B", "b")
		})
	}

}


private func makeParser(
	spaces: [SpacePattern],
	trivia: [String] = [],
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) throws -> Parser {
	try .init(
		grammars: [
			.init(
				name: "S",
				spaces: spaces,
				trivia: trivia,
				rules: [("root", "root", true, Syntax(body))],
			),
		],
	)
}
