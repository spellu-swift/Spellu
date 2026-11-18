//@testable import SpelluCore
//
//
//// 対象API: check(SpelluGrammar)。
//// 空・非公開のみ・公開あり、およびInterpreterへの組み込みを確認する。
//// priorityの整数検証では境界内外・極値とエラーの対象情報を確認する。
//@Suite struct GrammarCheckerTests {
//
//	@Test(arguments: [[Bool](), [false], [false, false]])
//	func 公開ルールがない文法を拒否する(exposes: [Bool]) {
//		let grammar: SpelluGrammar = checkerGrammar(exposes: exposes)
//		#expect(throws: SpelluError.noExposedRule(grammar: "Check")) {
//			try GrammarChecker.check(grammar)
//		}
//	}
//
//	@Test(arguments: [[true], [false, true], [true, false, true]])
//	func 公開ルールが一つ以上あれば受け入れる(exposes: [Bool]) throws {
//		try GrammarChecker.check(checkerGrammar(exposes: exposes))
//	}
//
//	@Test	func Interpreterの開始前に非公開のみの文法を拒否する() {
//		let grammar: SpelluGrammar = checkerGrammar(exposes: [false])
//		let interpreter: Interpreter = .init(grammars: [grammar])
//		#expect(throws: SpelluError.noExposedRule(grammar: "Check")) {
//			try interpreter.match(
//				source: "a",
//				method: .whole,
//				engine: .v2,
//				grammar: "Check",
//				rule: "rule0",
//			)
//		}
//	}
//
//	@Test func Syntax指定でも登録された文法を検証する() {
//		let interpreter: Interpreter = .init(
//			grammars: [checkerGrammar(exposes: [false])],
//		)
//		#expect(throws: SpelluError.noExposedRule(grammar: "Check")) {
//			try interpreter.match(
//				source: "a",
//				method: .whole,
//				engine: .v2,
//				syntax: Syntax { "a" },
//			)
//		}
//	}
//
//	@Test	func 公開ルールがある文法と内部の開始用文法は実行できる() throws {
//		let grammar: SpelluGrammar = checkerGrammar(exposes: [false, true])
//		let interpreter: Interpreter = .init(grammars: [grammar])
//		let node: SourceNode = try interpreter.match(
//			source: "a",
//			method: .whole,
//			engine: .v2,
//			grammar: "Check",
//			rule: "rule1",
//		)
//		#expect(node.string == "a")
//	}
//
//	@Test	func Interpreterは上下限のPathを持つ文法を実行できる() throws {
//		let grammar: SpelluGrammar = .init(
//			name: "PrecedenceCheck", spaces: [], trivia: [], rules: [
//				(name: "root", label: .none, expose: true,
//					syntax: Syntax {
//						AnyOf {
//							Branch(.min) { Fragment("a") }
//							Branch(.max) { Fragment("b") }
//						}
//					}),
//			],
//		)
//		let interpreter: Interpreter = .init(grammars: [grammar])
//		let node: SourceNode = try interpreter.match(
//			source: "a", method: .whole, engine: .v2,
//			grammar: grammar.name, rule: "root",
//		)
//		#expect(node.string == "a")
//	}
//}
//
//
//private func checkerGrammar(exposes: [Bool]) -> SpelluGrammar {
//	.init(
//		name: "Check",
//		spaces: [],
//		trivia: [],
//		rules: exposes.enumerated().map { index, expose in
//			(
//				name: "rule\(index)",
//				label: .none,
//				expose: expose,
//				syntax: Syntax { "a" },
//			)
//		},
//	)
//}
