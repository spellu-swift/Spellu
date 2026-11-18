import SpelluCore
@testable import SpelluInterpreter


// 観点：タグ環境・後方参照・Capture・Relabel。
// - tag付きの字句は読んだ範囲を記録し、後方参照は同じ文字列を読む。
// - 位置が同じでも記録が違えば別の経路として、後方参照まで保持する。
// - Captureは本文で記録したtagを外へ持ち出さない。失敗した候補の記録も引き継がない。
// - Relabelは返った木の一番上のラベルだけを付け替える。
// 期待値はCompatibleTestsとSpelluTestsのv4・Sakuya・Hooriと同じ。
@Suite struct InterpreterTagTests {

	// MARK: tagと後方参照

	@Test func tag付きの字句を後方参照で読む() throws {
		let parser: Parser = try makeParser {
			Fragment(label: "open", tag: "x") { "=".repeat(0...) }
			Fragment(":")
			Fragment(tag: "x")
		}
		#expect(try parser.parse("==:==", strategy: .asis).root.string == "==:==")
		#expect(try parser.parse(":", strategy: .asis).root.string == ":")
		#expect(throws: SpelluError.self) {
			try parser.parse("==:=", strategy: .asis).root
		}
	}

	@Test func 一致しない後方参照は記録した文字列を期待値にする() throws {
		let parser: Parser = try makeParser {
			Fragment(tag: "x", "ab")
			Fragment(tag: "x")
		}
		#expect {
			try parser.parse("abax", strategy: .asis).root
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 2 && expects == [.literal("ab")]
		}
	}

	@Test func 記録のない後方参照は期待値なしで失敗する() throws {
		let parser: Parser = try makeParser {
			Fragment("a")
			Fragment(tag: "x")
		}
		#expect {
			try parser.parse("aa", strategy: .asis).root
		} throws: { error in
			guard
				case let SpelluError.unexpected(_, offset, _, _, expects) = error
			else { return false }

			return offset == 1 && expects.isEmpty
		}
	}

	@Test func 同じ位置で記録が違う候補を後方参照まで保持する() throws {
		let parser: Parser = try makeParser {
			ChoiceOf {
				Sequence {
					Fragment(tag: "x", "a")
					Fragment("b")
				}
				Sequence {
					Fragment("a")
					Fragment(tag: "x", "b")
				}
			}
			Fragment(tag: "x")
		}
		#expect(try parser.parse("aba", strategy: .asis).root.string == "aba")
		#expect(try parser.parse("abb", strategy: .asis).root.string == "abb")
		#expect(throws: SpelluError.self) {
			try parser.parse("abc", strategy: .asis).root
		}
	}

	// MARK: Capture

	@Test func 空のCaptureは構文木にノードを追加しない() throws {
		let parser: Parser = try makeParser {
			Capture {}
			Fragment(label: "value", "a")
			Capture {}
		}
		let expected: TreeTuple<Label, String> = Tree(label: "root", "a") {
			Tree(label: "value", "a")
		}
		#expect(try parser.parse("a", strategy: .asis).root.asTreeTuple == expected)
		#expect(try parser.parse("a", strategy: .compact).root.asTreeTuple == expected)
	}

	@Test func 入れ子のCaptureを抜けるたびに外側のtagを復元する() throws {
		let parser: Parser = try makeParser {
			Fragment(label: "outer", tag: "x", "a")
			Capture {
				Fragment(tag: "x").as(label: "inherited")
				Fragment(label: "middle", tag: "x", "b")
				Capture {
					Fragment(label: "inner", tag: "x", "c")
					Fragment(tag: "x").as(label: "innerRef")
				}
				Fragment(tag: "x").as(label: "middleRef")
			}
			Fragment(tag: "x").as(label: "outerRef")
		}
		let source: String = "aabccba"
		let expected: TreeTuple<Label, String> = Tree(label: "root", source) {
			Tree(label: "outer", "a")
			Tree(label: "inherited", "a")
			Tree(label: "middle", "b")
			Tree(label: "inner", "c")
			Tree(label: "innerRef", "c")
			Tree(label: "middleRef", "b")
			Tree(label: "outerRef", "a")
		}
		#expect(try parser.parse(.temporary(source), strategy: .asis).root.asTreeTuple == expected)
		#expect(try parser.parse(.temporary(source), strategy: .compact).root.asTreeTuple == expected)
	}

	@Test func 失敗したCaptureの記録を次の候補へ引き継がない() throws {
		let parser: Parser = try makeParser {
			Fragment(label: "outer", tag: "x", "a")
			ChoiceOf {
				Capture {
					Fragment(tag: "x", "b")
					Fragment("!")
				}
				Fragment(label: "fallback", "b")
			}
			Fragment(tag: "x").as(label: "outerRef")
		}
		#expect(try parser.parse("aba", strategy: .asis).root.asTreeTuple == Tree(label: "root", "aba") {
			Tree(label: "outer", "a")
			Tree(label: "fallback", "b")
			Tree(label: "outerRef", "a")
		})
	}

	// MARK: Relabel

	@Test func Sequenceのラベルを付け直して子を保持する() throws {
		let parser: Parser = try makeParser {
			Sequence(label: "before") {
				Fragment(label: "left", "a")
				Fragment(label: "right", "b")
			}.as(label: "CHARACTER")
		}
		let expected: TreeTuple<Label, String> = Tree(label: "root", "ab") {
			Tree(label: "CHARACTER", "ab") {
				Tree(label: "left", "a")
				Tree(label: "right", "b")
			}
		}
		#expect(try parser.parse("ab", strategy: .asis).root.asTreeTuple == expected)
		#expect(try parser.parse("ab", strategy: .compact).root.asTreeTuple == expected)
	}

	@Test func Optionalが返す木のラベルを付け直す() throws {
		let parser: Parser = try makeParser {
			Optional {
				Fragment(label: "before", "a")
			}.as(label: "CHARACTER")
		}
		#expect(try parser.parse("a", strategy: .compact).root.asTreeTuple == Tree(label: "root", "a") {
			Tree(label: "CHARACTER", "a")
		})
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
