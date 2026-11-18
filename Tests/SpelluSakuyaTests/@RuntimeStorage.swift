import SpelluCore
@testable import SpelluSakuya

// 観点：一件目の重複、二件目への昇格、昇格後の重複と初出順、
// 同じ位置で異なるタグ環境、共有列の分割方法・衝突・走査順を確認する。
@Suite struct SakuyaRuntimeStorageTests {

	@Test func 同じ本文の導出では選ばれた一枝のTriviaを返す() throws {
		let evaluation: Evaluation = try makeEvaluation()
		let pool: SequencePool<TriviaSpan> = evaluation.session.store.triviaLists
		let span: TriviaSpan = .init(grammar: .init(index: 0), range: 0..<1, continuing: false)
		let trivia: Int = try pool.single(span)
		let output: InputState = .init(position: 1)
		try evaluation.publish(
			0,
			output,
			.init(action: .empty, trivia: .before(trivia))
		)
		try evaluation.publish(0, output, .init(action: .empty))

		let match: Session.Match = try SharedResolver(evaluation: evaluation)
			.select(evaluation.cells[0].resultOrder)

		#expect(match.trees == 0)
		#expect(try pool.values(match.trivia) == [span])
	}

	@Test func 到達とFamilyの検索表へ既存の一件も移す() throws {
		let evaluation: Evaluation = try makeEvaluation()
		let output: InputState = .init(position: 0)
		let empty: Family = .init(action: .empty)
		let join: Family = .init(action: .join)
		let ranked: Family = .init(action: .ranked(1))

		try evaluation.publish(0, output, empty)
		try evaluation.publish(0, output, empty)
		#expect(evaluation.cells[0].outputs.isEmpty)
		#expect(evaluation.results.count == 1)
		#expect(evaluation.results[0].knownFamilies.isEmpty)

		for family: Family in [join, empty, ranked, join, ranked] {
			try evaluation.publish(0, output, family)
		}
		#expect(evaluation.results[0].families == [empty, join, ranked])
		#expect(evaluation.results[0].knownFamilies.count == 3)

		let tagged: InputState = .init(position: 0, environment: 1)
		let moved: InputState = .init(position: 1)
		for state: InputState in [tagged, output, moved, tagged, moved] {
			try evaluation.publish(0, state, empty)
		}
		#expect(evaluation.cells[0].resultOrder == [0, 1, 2])
		#expect(evaluation.cells[0].outputs[output] == 0)
		#expect(evaluation.cells[0].outputs[tagged] == 1)
		#expect(evaluation.cells[0].outputs[moved] == 2)
		#expect(evaluation.results.count == 3)
	}

	@Test func 継続の検索表へ昇格しても重複を配信対象に加えない() throws {
		let evaluation: Evaluation = try makeEvaluation()
		let rule: RuleID = try evaluation.session.model.start(nil)
		let first: Evaluation.Continuation = .emit(0, .empty)
		let second: Evaluation.Continuation = .emit(0, .join)
		let third: Evaluation.Continuation = .emit(0, .ranked(1))

		for continuation: Evaluation.Continuation in [first, first] {
			try evaluation.request(
				.rule(rule),
				at: .init(position: 0),
				from: 0,
				then: continuation
			)
		}
		#expect(evaluation.cells[0].waiters == [first])
		#expect(evaluation.cells[0].knownWaiters.isEmpty)

		for continuation: Evaluation.Continuation in [
			second, first, third, second, third,
		] {
			try evaluation.request(
				.rule(rule),
				at: .init(position: 0),
				from: 0,
				then: continuation
			)
		}
		#expect(evaluation.cells[0].waiters == [first, second, third])
		#expect(evaluation.cells[0].knownWaiters.count == 3)
	}

	@Test func 共有列は分割方法が違っても一致し衝突した別内容は区別する() throws {
		let pool: SequencePool<CollidingValue> = .init(
			.init(maximum: SpelluSakuya.SafetyLimits.default.maxWork)
		)
		let a: Int = try pool.single(.init(value: 1))
		let b: Int = try pool.single(.init(value: 2))
		let c: Int = try pool.single(.init(value: 3))
		let ab: Int = try pool.joined(a, b)
		let ac: Int = try pool.joined(a, c)
		let bc: Int = try pool.joined(b, c)
		let abc: Int = try pool.joined(ab, c)

		#expect(try pool.joined(a, b) == ab)
		#expect(try pool.joined(a, bc) == abc)
		#expect(ab != ac)
		#expect(try pool.values(ab).map(\.value) == [1, 2])
		#expect(try pool.values(ac).map(\.value) == [1, 3])
		#expect(try pool.values(abc).map(\.value) == [1, 2, 3])
	}

}


private struct CollidingValue: Hashable {
	let value: Int

	func hash(into hasher: inout Hasher) {
		hasher.combine(0)
	}
}

private func makeEvaluation() throws -> Evaluation {
	let parser: Parser = try .init(
		grammars: [
			.init(
				name: "S",
				spaces: [],
				trivia: [],
				rules: [("root", "root", true, Syntax { Fragment("a") })]
			)
		]
	)
	let session: Session = .init(
		model: parser.model,
		source: "a",
		limits: .default,
		start: 0
	)
	return try .init(
		session: session,
		target: .rule(parser.model.start(nil)),
		input: .init(position: 0),
		mode: .init()
	)
}
