import Basis
import SpelluCore

struct InputState: Hashable {
	let position: Int
	var environment: Int = 0

	func moved(to position: Int) -> Self {
		.init(position: position, environment: environment)
	}
}

struct EvaluationMode: Hashable {
	var trivia: Bool = false
	var silent: Bool = false
}

enum ParseFailure: Error { case noMatch }


final class Session {

	typealias Environment = [GrammarID: [String: Range<Int>]]
	enum Expectation: Hashable {
		case token(LexemeID, Int, Int)
		case words(LexemeID)
		case value(Expect)
	}
	struct Match {
		let output: InputState
		let trees: Int
		let trivia: Int
	}
	private struct Active: Hashable {
		let expression: ExprID
		let position: Int
	}
	private struct Frame {
		let evaluation: Evaluation
		let active: Active?
		let returnTo: BoundaryRequest?
	}

	let model: GrammarModel
	let source: Source
	let limits: SafetyLimits
	let budget: WorkBudget
	let store: DerivationStore
	private var environments: [Environment] = [[:]]
	private var environmentIDs: [Environment: Int] = [[:]: 0]
	private var failurePosition: Int
	private var expectations: [Expectation] = []
	private var knownExpectations: Set<Expectation> = []

	init(model: GrammarModel, source: Source, limits: SafetyLimits, start: Int)
	{
		self.model = model
		self.source = source
		self.limits = limits
		failurePosition = start
		let budget: WorkBudget = .init(maximum: limits.maxWork)
		self.budget = budget
		store = .init(budget)
	}

	func input(_ position: Int) -> SourceStream {
		var stream: SourceStream = .init(
			source,
			engine: .momojiri,
			maxTokenRepetition: limits.maxTokenRepetition
		)
		stream.offset = position
		return stream
	}

	func capture(
		_ range: Range<Int>,
		tag: String,
		owner: GrammarID,
		state: InputState
	) throws -> Int {
		var values: Environment = environments[state.environment]
		values[owner, default: [:]][tag] = range
		if let id: Int = environmentIDs[values] {
			return id
		}
		try budget.spend()
		let id: Int = environments.count
		environments.append(values)
		environmentIDs[values] = id
		return id
	}

	func captured(_ tag: String, owner: GrammarID, state: InputState) -> Range<
		Int
	>? { environments[state.environment][owner]?[tag] }

	func record(_ position: Int, _ expectation: Expectation? = nil) {
		guard position >= failurePosition else { return }
		if position > failurePosition {
			failurePosition = position
			expectations.removeAll(keepingCapacity: true)
			knownExpectations.removeAll(keepingCapacity: true)
		}
		if let expectation, knownExpectations.insert(expectation).inserted {
			expectations.append(expectation)
		}
	}

	func diagnostic() -> SpelluError {
		var values: Set<Expect> = []
		for expectation: Expectation in expectations {
			switch expectation {
				case .token(let id, let start, let failed):
					let stream: SourceStream = input(start)
					let position: String.Index = source.content.utf8Index(
						failed
					)
					values.formUnion(
						model.lexemes[id.index].pattern.expectations(
							in: stream,
							at: position
						)
					)
				case .words(let id):
					values.formUnion(
						(model.lexemes[id.index].words ?? []).map(
							Expect.literal
						)
					)
				case .value(let value): values.insert(value)
			}
		}
		let (line, column): (Int, Int) = source.position(failurePosition)
		return .unexpected(
			source: source,
			offset: failurePosition,
			line: line,
			column: column,
			expects: Array(values).sorted
		)
	}

	func parse(_ rule: RuleID, at start: Int, whole: Bool) throws -> Match {
		let target: Evaluation.Target = whole ? .whole(rule) : .rule(rule)
		var activeEntries: Set<Active> = []
		var frames: [Frame] = [
			.init(
				evaluation: try .init(
					session: self,
					target: target,
					input: .init(position: start),
					mode: .init()
				),
				active: nil,
				returnTo: nil
			)
		]
		while let frame: Frame = frames.last {
			do {
				switch try frame.evaluation.advance() {
					case .boundary(let request):
						let key: Active = .init(
							expression: request.expression,
							position: request.input.position
						)
						guard activeEntries.insert(key).inserted else {
							throw SpelluError.safetyStop(
								.other("Recursive prefix match")
							)
						}
						guard frames.count < limits.maxSyntaxRepetition else {
							throw SpelluError.safetyStop(
								.overLimitsOfRecursion(
									limits: limits.maxSyntaxRepetition
								)
							)
						}
						frames.append(
							.init(
								evaluation: try .init(
									session: self,
									target: .boundary(request.expression),
									input: request.input,
									mode: request.mode,
									collectsTrivia: frame.evaluation.collectsTrivia
										&& !request.probe
								),
								active: key,
								returnTo: request
							)
						)
					case .matched(let match):
						frames.removeLast()

						if let active: Active = frame.active {
							activeEntries.remove(active)
						}

						guard let parent: Frame = frames.last,
							let request: BoundaryRequest = frame.returnTo
						else { return match }
						try parent.evaluation.resume(request, match)
				}
			} catch ParseFailure.noMatch {
				frames.removeLast()

				if let active: Active = frame.active {
					activeEntries.remove(active)
				}

				if frame.returnTo == nil {
					throw diagnostic()
				}
			}
		}
		throw diagnostic()
	}

}
