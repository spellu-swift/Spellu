import SpelluCore
@testable import SpelluSakuya

// API観点：既定値・個別指定・補正、作業量と到達数の境界、
// Parser/Generatorへの伝播、重複到達とタグ環境、解析ごとの分離を確認する。
@Suite struct SakuyaSafetyLimitsTests {

	@Test func 省略と指定値と上下限の補正を確認する() {
		let defaults: SpelluSakuya.SafetyLimits = .default
		#expect(defaults.maxSyntaxRepetition == 1000)
		#expect(defaults.maxTokenRepetition == 65535)
		#expect(defaults.maxWork == 1_000_000)
		#expect(defaults.maxRuleArrivals == 4096)
		let specified: SpelluSakuya.SafetyLimits = .init(
			maxSyntaxRepetition: 20,
			maxTokenRepetition: 2048,
			maxWork: 2000,
			maxRuleArrivals: 2
		)
		#expect(specified.maxSyntaxRepetition == 20)
		#expect(specified.maxTokenRepetition == 2048)
		#expect(specified.maxWork == 2000)
		#expect(specified.maxRuleArrivals == 2)
		let lower: SpelluSakuya.SafetyLimits = .init(
			maxSyntaxRepetition: -1,
			maxTokenRepetition: -1,
			maxWork: -1,
			maxRuleArrivals: -1
		)
		#expect(lower.maxSyntaxRepetition == 16)
		#expect(lower.maxTokenRepetition == 1024)
		#expect(lower.maxWork == 1000)
		#expect(lower.maxRuleArrivals == 1)
		let upper: SpelluSakuya.SafetyLimits = .init(
			maxSyntaxRepetition: Int.max,
			maxTokenRepetition: Int.max,
			maxWork: Int.max,
			maxRuleArrivals: Int.max
		)
		#expect(upper.maxSyntaxRepetition == Int.max - 1)
		#expect(upper.maxTokenRepetition == Int.max - 1)
		#expect(upper.maxWork == Int.max - 1)
		#expect(upper.maxRuleArrivals == Int.max - 1)
		#expect(SpelluSakuya.SafetyLimits(maxWork: 2000).maxRuleArrivals == 4096)
	}

	@Test func 作業予算は指定回数まで使え超過後も安全停止する() throws {
		let budget: WorkBudget = .init(maximum: 1_000_001)
		for _ in 0..<1_000_001 {
			try budget.spend()
		}
		for _ in 0..<2 {
			#expect(throws: SpelluError.safetyStop(
				.other("Sakuya work limit exceeded (1000001)")
			)) { try budget.spend() }
		}
		let zero: WorkBudget = .init(maximum: 0)
		#expect(throws: SpelluError.self) { try zero.spend() }
	}

	@Test func 作業量を引き上げれば解析でき予算を解析ごとに作り直す() throws {
		let source: Source = .temporary(String(repeating: "a", count: 256))
		let grammar: SpelluGrammar = makeGrammar {
			Repeat(256...256) { Fragment("a") }
		}
		let small: Parser = try .init(
			grammars: [grammar],
			limits: .init(maxWork: 1000),
		)
		#expect(throws: SpelluError.safetyStop(
			.other("Sakuya work limit exceeded (1000)")
		)) { try small.parse(source, strategy: .asis).root }
		#expect(throws: SpelluError.safetyStop(
			.other("Sakuya work limit exceeded (1000)")
		)) {
			try Parser(
				grammars: [grammar],
				limits: .init(maxWork: 1000),
			).parse(
				source,
				strategy: .asis,
			)
		}
		let large: Parser = try .init(
			grammars: [grammar],
			limits: .init(maxWork: 100_000),
		)
		for _ in 0..<2 {
			#expect(try large.parse(source, strategy: .asis).root.range == 0..<256)
		}
	}

	@Test func 到達数を引き上げれば同じ入力を解析できる() throws {
		let grammar: SpelluGrammar = makeGrammar {
			ChoiceOf {
				Fragment("a")
				Fragment("ab")
				Fragment("abc")
			}
		}
		let small: Parser = try .init(
			grammars: [grammar],
			limits: .init(maxRuleArrivals: 2),
		)
		#expect(throws: SpelluError.safetyStop(
			.other("Sakuya rule arrival limit exceeded (2)")
		)) { try small.parse("abc", strategy: .asis) }
		let large: Parser = try .init(
			grammars: [grammar],
			limits: .init(maxRuleArrivals: 3),
		)
		#expect(try large.parse("abc", strategy: .asis).root.string == "abc")
	}

	@Test(arguments: [1, 4097])
	func 到達上限でも同じ状態の追加導出は許しタグ環境の違いは数える(
		maximum: Int
	) throws {
		let parser: Parser = try .init(grammars: [makeGrammar { Fragment("a") }])
		let session: Session = .init(
			model: parser.model,
			source: "a",
			limits: .init(maxRuleArrivals: maximum),
			start: 0
		)
		let evaluation: Evaluation = try .init(
			session: session,
			target: .rule(parser.model.start(nil)),
			input: .init(position: 0),
			mode: .init()
		)
		for environment: Int in 0..<maximum {
			try evaluation.publish(
				0,
				.init(position: 0, environment: environment),
				.init(action: .empty),
			)
		}
		try evaluation.publish(0, .init(position: 0), .init(action: .join))
		#expect(evaluation.results.count == maximum)
		#expect(evaluation.results[0].families.count == 2)
		#expect(throws: SpelluError.safetyStop(
			.other("Sakuya rule arrival limit exceeded (\(maximum))")
		)) {
			try evaluation.publish(
				0,
				.init(position: 0, environment: maximum),
				.init(action: .empty),
			)
		}
	}
}

private func makeGrammar(@SyntaxBuilder _ body: () -> [SyntaxIR])
	-> SpelluGrammar
{
	.init(name: "S", spaces: [], trivia: [], rules: [("root", "root", true, Syntax(body))])
}
