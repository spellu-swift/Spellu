import Basis
import SpelluCore
import SpelluLex

struct LoopState: Hashable {
	var count: Int = 0
	var emptyCount: Int = 0
}


enum DerivationAction: Hashable {
	case empty
	case join
	case ranked(Int)
	case scope(ScopeID, GrammarID, Label?)
	case optional(ScopeID, ScopeID, Bool)
	case relabel(Label)
	case leaf(Int, PathAtom)
	case committed(Int, PathAtom)
	case iteration(ExprID, LoopState, Int, final: Bool)
	case stop(ExprID, LoopState, Int)
	case limit
}


struct Family: Hashable {
	let action: DerivationAction
	var children: [Int] = []
	var trivia: TriviaContribution = .none
}

struct ArrivalResult {
	let output: InputState
	var families: [Family]
	// 一件の間はfamiliesを直接比較し、二件目で検索表を作る。
	var knownFamilies: Set<Family>
}

struct BoundaryRequest {
	let parent: Int
	let expression: ExprID
	let input: InputState
	let mode: EvaluationMode
	let atom: PathAtom
	let probe: Bool
}


final class Evaluation {

	enum Target: Hashable {
		case rule(RuleID)
		case whole(RuleID)
		case expression(ExprID, prepared: Bool = false)
		case sequence(ExprID, Int)
		case loop(ExprID)
		case prefix(Int, LoopState)
		case boundary(ExprID)
		case trivia(GrammarID)
		case eos(GrammarID)
	}
	struct Key: Hashable {
		let target: Target
		let input: InputState
		let mode: EvaluationMode
	}
	enum Continuation: Hashable {
		case emit(Int, DerivationAction)
		case restore(Int, Int)
		case head(Int, ExprID, Int)
		case tail(Int, Int)
		case prepared(Int, ExprID)
		case preparedBody(Int, Int)
		case prefix(Int, ExprID, LoopState)
		case body(Int, ExprID, LoopState, Int)
		case first(Int, ExprID)
		case rest(Int, ExprID, Int)
		case separator(Int, ExprID, Int, Int)
		case triviaSyntax(Int, GrammarID, Int)
		case triviaRest(Int, GrammarID, Range<Int>)
		case requiredTrivia(Int, GrammarID)
		case eos(Int)
		case ending(Int, GrammarID)
		case ended(Int, Int)
	}
	struct Cell {
		let key: Key
		// 順序は配列で保持し、検索表は二件以上の場合だけ使う。
		var outputs: [InputState: Int] = [:]
		var resultOrder: [Int] = []
		var waiters: [Continuation] = []
		var knownWaiters: Set<Continuation> = []
	}
	private struct PrefixKey: Hashable {
		let root: Int
		let state: LoopState
	}
	private enum Work {
		case evaluate(Int)
		case deliver(Continuation, Int)
	}
	enum Event {
		case boundary(BoundaryRequest)
		case matched(Session.Match)
	}

	let session: Session
	let collectsTrivia: Bool
	private(set) var cells: [Cell] = []
	private(set) var results: [ArrivalResult] = []
	private var calls: [Key: Int] = [:]
	private var prefixes: [PrefixKey: Int] = [:]
	private var work: Deque<Work> = []

	init(
		session: Session,
		target: Target,
		input: InputState,
		mode: EvaluationMode,
		collectsTrivia: Bool = true
	) throws {
		self.session = session
		self.collectsTrivia = collectsTrivia
		_ = try cell(.init(target: target, input: input, mode: mode))
	}

	private func enqueue(_ item: Work) throws {
		try session.budget.spend()
		work.append(item)
	}

	private func cell(_ key: Key) throws -> Int {
		let shared: Bool
		switch key.target {
			case .rule, .trivia:
				shared = true
			default:
				shared = false
		}

		if shared, let id: Int = calls[key] {
			return id
		}
		let id: Int = cells.count
		cells.append(.init(key: key))
		if shared {
			calls[key] = id
		}
		try enqueue(.evaluate(id))
		return id
	}

	func request(
		_ target: Target,
		at input: InputState,
		from parent: Int,
		then continuation: Continuation,
		mode: EvaluationMode? = nil
	) throws {
		let id: Int = try cell(
			.init(
				target: target,
				input: input,
				mode: mode ?? cells[parent].key.mode
			)
		)
		if cells[id].waiters.count == 1 {
			let first: Continuation = cells[id].waiters[0]
			guard first != continuation else { return }
			cells[id].knownWaiters = [first, continuation]
		} else if cells[id].waiters.count > 1 {
			guard cells[id].knownWaiters.insert(continuation).inserted else {
				return
			}
		}
		cells[id].waiters.append(continuation)
		for result: Int in cells[id].resultOrder {
			try enqueue(.deliver(continuation, result))
		}
	}

	func publish(_ parent: Int, _ output: InputState, _ family: Family) throws {
		let existing: Int?
		if cells[parent].resultOrder.count == 1 {
			let first: Int = cells[parent].resultOrder[0]
			existing = results[first].output == output ? first : nil
		} else {
			existing = cells[parent].outputs[output]
		}
		if let result: Int = existing {
			// 自動Triviaは到達だけを本文に渡す。同じ到達の読み方は一つだけ残す。
			if case .trivia = cells[parent].key.target {
				keepLongerReading(family, at: result)
				return
			}
			let isNew: Bool
			if results[result].families.count == 1 {
				let first: Family = results[result].families[0]
				isNew = first != family
				if isNew {
					results[result].knownFamilies = [first, family]
				}
			} else {
				isNew = results[result].knownFamilies.insert(family).inserted
			}
			if isNew {
				try session.budget.spend()
				results[result].families.append(family)
			}
			return
		}
		if case .rule = cells[parent].key.target,
			cells[parent].resultOrder.count >= session.limits.maxRuleArrivals
		{
			throw SpelluError.safetyStop(
				.other(
					"Sakuya rule arrival limit exceeded "
						+ "(\(session.limits.maxRuleArrivals))"
				)
			)
		}
		try session.budget.spend()
		let result: Int = results.count
		results.append(
			.init(output: output, families: [family], knownFamilies: [])
		)
		if cells[parent].resultOrder.count == 1 {
			let first: Int = cells[parent].resultOrder[0]
			cells[parent].outputs[results[first].output] = first
		}
		if !cells[parent].resultOrder.isEmpty {
			cells[parent].outputs[output] = result
		}
		cells[parent].resultOrder.append(result)
		for continuation: Continuation in cells[parent].waiters {
			try enqueue(.deliver(continuation, result))
		}
	}

	func record(
		_ cell: Int,
		_ offset: Int,
		_ expectation: Session.Expectation? = nil
	) {
		if !cells[cell].key.mode.silent {
			session.record(offset, expectation)
		}
	}

	func loop(_ id: ExprID) -> GrammarModel.LoopPlan {
		guard
			case .repetition(let plan) = session.model.expressions[id.index]
				.kind
		else { preconditionFailure() }
		return plan
	}

	func prefix(_ root: Int, _ expression: ExprID, _ state: LoopState) throws
		-> Int
	{
		let key: PrefixKey = .init(root: root, state: state)
		if let id: Int = prefixes[key] {
			return id
		}
		let original: Key = cells[root].key
		let id: Int = try cell(
			.init(
				target: .prefix(root, state),
				input: original.input,
				mode: original.mode
			)
		)
		prefixes[key] = id
		let continuation: Continuation = .prefix(root, expression, state)
		cells[id].waiters = [continuation]
		return id
	}

	func advance() throws -> Event {
		while let item: Work = work.popFirst() {
			switch item {
				case .evaluate(let id):
					if let boundary: BoundaryRequest = try evaluate(id) {
						return .boundary(boundary)
					}
				case .deliver(let continuation, let result):
					try deliver(continuation, result)
			}
		}
		try resolveAutoTrivia()
		let resolver: SharedResolver = .init(evaluation: self)
		return .matched(try resolver.select(finalRoots()))
	}

	/// 同じ到達の読み方のうち、先頭の構文Triviaが最も長いものを残す。
	///
	/// 残りの読み飛ばしも到達ごとに同じ規則で残すので、先頭から順に各構文Triviaが
	/// 最も長くなる読み方になり、到着の順には依存しない。
	private func keepLongerReading(_ family: Family, at result: Int) {
		guard
			case .step(_, let range, _) = family.trivia,
			case .step(_, let current, _) = results[result].families[0].trivia,
			range.upperBound > current.upperBound
		else { return }

		results[result].families[0] = family
	}

	/// 認識が終わった後で、自動Triviaの到達への参照を範囲の列へ置き換える。
	private func resolveAutoTrivia() throws {
		var tails: [Int: Int] = [:]

		for result: Int in results.indices {
			for index: Int in results[result].families.indices {
				switch results[result].families[index].trivia {
					case .beforeArrival(let arrival):
						results[result].families[index].trivia
						= try .before(triviaList(of: arrival, &tails))
					case .afterArrival(let arrival):
						results[result].families[index].trivia
						= try .after(triviaList(of: arrival, &tails))
					default:
						break
				}
			}
		}
	}

	/// 自動Triviaの到達で読み飛ばした範囲の列。
	private func triviaList(
		of arrival: Int,
		_ tails: inout [Int: Int]
	) throws -> Int {
		guard
			case .step(let owner, let range, let rest)
				= results[arrival].families[0].trivia
		else { return 0 }

		let pool: SequencePool<TriviaSpan> = session.store.triviaLists

		return try pool.joined(
			pool.single(.init(grammar: owner, range: range, continuing: false)),
			triviaTail(of: rest, &tails)
		)
	}

	/// 読み飛ばしの二番目以降の範囲の列。同じ到達を読む経路の間で共有する。
	private func triviaTail(
		of root: Int,
		_ tails: inout [Int: Int]
	) throws -> Int {
		var chain: [Int] = []
		var current: Int = root

		while tails[current] == nil,
			case .step(_, _, let rest) = results[current].families[0].trivia
		{
			chain.append(current)
			current = rest
		}

		let pool: SequencePool<TriviaSpan> = session.store.triviaLists
		var tail: Int = tails[current] ?? 0

		for result: Int in chain.reversed() {
			guard
				case .step(let owner, let range, _)
					= results[result].families[0].trivia
			else { continue }

			tail = try pool.joined(
				pool.single(.init(grammar: owner, range: range, continuing: true)),
				tail
			)
			tails[result] = tail
		}

		return tail
	}

	func resume(_ request: BoundaryRequest, _ match: Session.Match) throws {
		if request.probe {
			try publish(request.parent, request.input, .init(action: .empty))
			return
		}

		try publish(
			request.parent,
			match.output,
			.init(
				action: .committed(match.trees, request.atom),
				trivia: match.trivia == 0 ? .none : .before(match.trivia)
			)
		)
	}

	private func boundary(
		_ cell: Int,
		_ expression: ExprID,
		_ atom: PathAtom,
		probe: Bool = false
	) -> BoundaryRequest {
		let key: Key = cells[cell].key
		var mode: EvaluationMode = key.mode
		mode.silent = mode.silent || probe
		return .init(
			parent: cell,
			expression: expression,
			input: key.input,
			mode: mode,
			atom: atom,
			probe: probe
		)
	}

	private func evaluate(_ id: Int) throws -> BoundaryRequest? {
		let key: Key = cells[id].key
		let model: GrammarModel = session.model
		switch key.target {
			case .rule(let rule):
				let info: GrammarModel.Rule = model.rules[rule.index]
				try request(
					.expression(info.body),
					at: key.input,
					from: id,
					then: .emit(
						id,
						.scope(info.scope, info.grammar, info.label)
					)
				)
			case .whole(let rule):
				try request(
					.rule(rule),
					at: key.input,
					from: id,
					then: .ending(id, model.rules[rule.index].grammar)
				)
			case .sequence(let expression, let next):
				guard
					case .sequence(let parts) = model.expressions[
						expression.index
					].kind
				else { preconditionFailure() }
				if next == parts.count {
					try publish(id, key.input, .init(action: .empty))
				} else {
					try request(
						.expression(parts[next]),
						at: key.input,
						from: id,
						then: .head(id, expression, next + 1)
					)
				}
			case .expression(let expression, let prepared):
				let info: GrammarModel.Expression = model.expressions[
					expression.index
				]
				let needsTrivia: Bool
				switch info.kind {
					case .lexical(let lexeme):
						needsTrivia = model.lexemes[lexeme.index].spacious
					case .tokenReference(_, let spacious, _):
						needsTrivia = spacious
					case .eos: needsTrivia = true
					default: needsTrivia = false
				}
				if needsTrivia && !prepared && !key.mode.trivia {
					try request(
						.trivia(info.grammar),
						at: key.input,
						from: id,
						then: .prepared(id, expression),
						mode: .init(trivia: true, silent: true)
					)
					return nil
				}
				return try evaluate(expression, info, id)
			case .boundary(let expression):
				let info: GrammarModel.Expression = model.expressions[
					expression.index
				]
				guard case .atomic(let body, let scope, _) = info.kind else {
					preconditionFailure()
				}
				try request(
					.expression(body),
					at: key.input,
					from: id,
					then: .emit(id, .scope(scope, info.grammar, "#atomic"))
				)
			case .loop(let expression):
				let prefix: Int = try prefix(id, expression, .init())
				try publish(prefix, key.input, .init(action: .empty))
			case .prefix: break
			case .trivia(let owner): try scanTrivia(id, owner)
			case .eos(let owner):
				if key.mode.trivia {
					try end(id, key.input)
				} else {
					try request(
						.trivia(owner),
						at: key.input,
						from: id,
						then: .eos(id),
						mode: .init(trivia: true, silent: true)
					)
				}
		}
		return nil
	}

	private func evaluate(
		_ expression: ExprID,
		_ info: GrammarModel.Expression,
		_ id: Int
	) throws -> BoundaryRequest? {
		let key: Key = cells[id].key
		switch info.kind {
			case .empty:
				try publish(id, key.input, .init(action: .empty))
			case .point(let atom):
				let tree: Int = try session.store.branch(
					info.grammar,
					"#nil",
					0,
					key.input.position
				)
				try publish(
					id,
					key.input,
					.init(action: .leaf(tree, .model(atom)))
				)
			case .fail:
				record(id, key.input.position, .value(.character("NEVER")))
			case .sequence:
				try request(
					.sequence(expression, 0),
					at: key.input,
					from: id,
					then: .emit(id, .join)
				)
			case .group(let body, let scope, let label):
				try request(
					.expression(body),
					at: key.input,
					from: id,
					then: .emit(id, .scope(scope, info.grammar, label))
				)
			case .choice(let branches):
				for branch: GrammarModel.Branch in branches {
					try request(
						.expression(branch.body),
						at: key.input,
						from: id,
						then: .emit(id, .ranked(branch.rank))
					)
				}
			case .optional(let body, let outer, let inner):
				try publish(
					id,
					key.input,
					.init(action: .optional(outer, inner, false))
				)
				try request(
					.expression(body),
					at: key.input,
					from: id,
					then: .emit(id, .optional(outer, inner, true))
				)
			case .repetition(let plan):
				try request(
					.loop(expression),
					at: key.input,
					from: id,
					then: .emit(id, .scope(plan.scope, info.grammar, nil))
				)
			case .list(let plan):
				if plan.minimum == 0 {
					try publish(
						id,
						key.input,
						.init(action: .scope(plan.scope, info.grammar, nil))
					)
				}
				if plan.maximum != 0 {
					try request(
						.expression(plan.body),
						at: key.input,
						from: id,
						then: .first(id, expression)
					)
				}
			case .lexical(let lexeme): try scan(id, lexeme, owner: info.grammar)
			case .reference(let rule):
				try request(
					.rule(rule),
					at: key.input,
					from: id,
					then: .emit(id, .join)
				)
			case .tokenReference(let tag, let spacious, let atom):
				try scanReference(id, tag, spacious, atom, info.grammar)
			case .capture(let body):
				try request(
					.expression(body),
					at: key.input,
					from: id,
					then: .restore(id, key.input.environment)
				)
			case .atomic(_, let scope, let probe):
				return boundary(
					id,
					expression,
					.scope(.fixed(scope)),
					probe: probe
				)
			case .relabel(let body, let label):
				try request(
					.expression(body),
					at: key.input,
					from: id,
					then: .emit(id, .relabel(label))
				)
			case .trivia:
				var mode: EvaluationMode = key.mode
				mode.trivia = true
				try request(
					.trivia(info.grammar),
					at: key.input,
					from: id,
					then: .requiredTrivia(id, info.grammar),
					mode: mode
				)
			case .eos: try end(id, key.input)
		}
		return nil
	}

	func end(
		_ id: Int, _ reached: InputState, trivia: TriviaContribution = .none
	) throws {
		if reached.position == session.source.range.upperBound {
			try publish(id, reached, .init(action: .empty, trivia: trivia))
		} else {
			record(id, reached.position, .value(.eos))
		}
	}

	private func singleLiteral(_ plan: GrammarModel.LoopPlan) -> Bool {
		guard
			case .lexical(let id) = session.model.expressions[plan.body.index]
				.kind
		else { return false }
		let value: GrammarModel.Lexeme = session.model.lexemes[id.index]
		guard !value.spacious, value.tag == nil, value.words == nil,
			value.pattern.amount == .exactly(1),
			case .string(let text) = value.pattern.factor
		else { return false }
		return !text.isEmpty
	}

	func rejectStop(_ expression: ExprID, _ reached: InputState) -> Bool {
		guard case .whole(let rule) = cells[0].key.target else { return false }
		let info: GrammarModel.Rule = session.model.rules[rule.index]
		let trivia: GrammarModel.TriviaPlan = session.model.grammars[
			info.grammar.index
		].trivia
		guard expression == info.body, !trivia.hasLexical,
			trivia.syntax.isEmpty, singleLiteral(loop(expression)),
			reached.position < session.source.range.upperBound
		else { return false }
		session.record(reached.position, .value(.eos))
		return true
	}

	private func finalRoots() -> [Int] {
		let roots: [Int] = cells[0].resultOrder
		guard roots.count > 1, case .rule(let rule) = cells[0].key.target,
			case .repetition(let plan) = session.model.expressions[
				session.model.rules[rule.index].body.index
			].kind, plan.maximum == nil, singleLiteral(plan)
		else { return roots }
		let selected: Int? = roots.max {
			plan.behavior == .eager
				? results[$0].output.position < results[$1].output.position
				: results[$0].output.position > results[$1].output.position
		}
		return selected.map { [$0] } ?? roots
	}

}
