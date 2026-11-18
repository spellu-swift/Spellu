import SpelluCore
import SpelluHoori

// API観点：HooriLimits.initの既定値・省略・負の値と、各上限の安全停止を確認する。
@Suite struct HooriLimitsTests {

	@Test func 省略した上限は既定値になる() {
		let limits: HooriLimits = .init()

		#expect(limits.maxTokenRepetition == HooriLimits.DEFAULT_MAX_TOKEN_REPETITION)
		#expect(limits.maxBoundaryDepth == HooriLimits.DEFAULT_MAX_BOUNDARY_DEPTH)
		#expect(limits.maxEmptyRepetition == HooriLimits.DEFAULT_MAX_EMPTY_REPETITION)
		#expect(limits.maxWork == HooriLimits.DEFAULT_MAX_WORK)
		#expect(HooriLimits.default == limits)
	}

	@Test func 指定した上限を保持し負の値は0にする() {
		let limits: HooriLimits = .init(
			maxTokenRepetition: 1,
			maxBoundaryDepth: 2,
			maxEmptyRepetition: -3,
			maxWork: 4,
		)

		#expect(limits.maxTokenRepetition == 1)
		#expect(limits.maxBoundaryDepth == 2)
		#expect(limits.maxEmptyRepetition == 0)
		#expect(limits.maxWork == 4)
	}

	@Test func 総作業量の上限で安全停止し途中の候補を返さない() throws {
		let parser: Parser = try makeParser(.init(maxWork: 3)) {
			Fragment("a")
			Fragment("b")
		}

		#expect(throws: SpelluError.safetyStop(.other("Hoori work limit exceeded (3)"))) {
			try parser.parse("ab", strategy: .asis)
		}
	}

	@Test func 総作業量を引き上げれば同じ文法で解析できる() throws {
		let source: Source = .temporary(String(repeating: "a", count: 2000))
		let small: Parser = try makeParser(.init(maxWork: 1000)) {
			Repeat { Fragment("a") }
		}
		let large: Parser = try makeParser(.init(maxWork: 10_000_000)) {
			Repeat { Fragment("a") }
		}

		#expect(throws: SpelluError.self) {
			try small.parse(source, strategy: .asis)
		}
		#expect(try large.parse(source, strategy: .asis).root.range == 0..<2000)
	}

	@Test func 曖昧さが増え続ける文法は総作業量の上限で止まる() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				("A", "A", true, Syntax {
					ChoiceOf {
						Sequence {
							RuleReference.rule("A")
							RuleReference.rule("A")
						}
						Fragment("a")
					}
				}),
			],
		)
		let parser: Parser = try .init(
			grammars: [grammar],
			limits: .init(maxWork: 100_000),
		)

		#expect(throws: SpelluError.safetyStop(.other("Hoori work limit exceeded (100000)"))) {
			try parser.parse(
				.temporary(String(repeating: "a", count: 64)),
				strategy: .asis,
			)
		}
	}

	@Test func 確定範囲の深さの上限で安全停止する() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				("A", "A", true, Syntax {
					Fragment("a")
					Optional {
						Atomic { RuleReference.rule("A") }
					}
				}),
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

	@Test func 必須回数に届くまでの無消費反復の上限で安全停止する() throws {
		let parser: Parser = try makeParser(.init(maxEmptyRepetition: 1)) {
			Repeat(3...3) {
				Optional { Fragment("a") }
			}
		}

		#expect(throws: SpelluError.safetyStop(.overLimitsOfRepetition(limits: 1))) {
			try parser.parse("", strategy: .asis)
		}
	}

	@Test func 同じ位置で同じAtomicへ戻ると安全停止する() throws {
		let grammar: SpelluGrammar = .init(
			name: "S",
			spaces: [],
			trivia: [],
			rules: [
				("A", "A", true, Syntax {
					ChoiceOf {
						Atomic { RuleReference.rule("A") }
						Fragment("a")
					}
				}),
			],
		)
		let parser: Parser = try .init(grammars: [grammar])

		#expect(throws: SpelluError.safetyStop(.other("Recursive prefix match"))) {
			try parser.parse("a", strategy: .asis)
		}
	}

	@Test func 基底のない文法間の左再帰は不一致になる() throws {
		let first: SpelluGrammar = .init(
			name: "F",
			spaces: [],
			trivia: [],
			rules: [
				("a", "a", true, Syntax {
					RuleReference.grammar("G", rule: "b")
				}),
			],
		)
		let second: SpelluGrammar = .init(
			name: "G",
			spaces: [],
			trivia: [],
			rules: [
				("b", "b", true, Syntax {
					RuleReference.grammar("F", rule: "a")
				}),
			],
		)
		let parser: Parser = try .init(grammars: [first, second])

		#expect {
			try parser.parse("x", strategy: .asis)
		} throws: { error in
			if case SpelluError.unexpected = error {
				return true
			}

			return false
		}
	}

}


private func makeParser(
	_ limits: HooriLimits,
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
		limits: limits,
	)
}
