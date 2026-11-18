import SpelluCore

/// 導出が一つと証明できる森だけを評価する。候補配列は作らない。
final class SingleDerivation {
	let evaluation: Evaluation
	let store: DerivationStore
	init(_ evaluation: Evaluation) { self.evaluation = evaluation; store = evaluation.session.store }
	func evaluate(_ forest: PackedPlan, root: Int) throws -> Session.Match {
		var values: [Int: Candidate] = [:]
		for id in 0...root {
			try store.budget.spend()
			let plan = forest.plans[id]
			guard plan.families.count == 1 else { continue }
			let family = plan.families[0]
			var value = Candidate()
			for (index, child) in family.children.enumerated() {
				guard let body = values[child] else { preconditionFailure() }
				if index == 0 { value = body; continue }
				if case let .iteration(expression, state, rank, _) = family.action, index == 1 {
					let loop = evaluation.loop(expression)
					value = try .init(history: store.iteration(.init(previous: value.history,
					scope: control(loop, state), rank: rank,
					body: store.enclosed(body, in: .fixed(loop.bodyScope)))))
				} else { value = try store.joined(value, body) }
			}
			values[id] = try transform(family.action, value, forest.results[plan.result].output.position)
		}

		let plan: PackedPlan.Plan = forest.plans[root]
		let trivia: Int
		if plan.hasTrivia {
			trivia = try forest.collectTrivia(from: root) { id in
				let branch: PackedPlan.Branch = forest.plans[id].families[0]
				return .init(
					contribution: branch.trivia,
					children: branch.children.filter {
						forest.plans[$0].hasTrivia
					}
				)
			}
		} else {
			trivia = 0
		}

		return .init(
			output: forest.results[plan.result].output,
			trees: values[root]!.trees,
			trivia: trivia
		)
	}
	private func control(_ plan: GrammarModel.LoopPlan, _ state: LoopState)
		-> ScopeKey
	{
		.loop(
			plan.control,
			Swift.max(plan.minimum - state.count, 0),
			plan.maximum.map { $0 - state.count }
		)
	}

	private func transform(
		_ action: DerivationAction,
		_ value: Candidate,
		_ end: Int
	) throws -> Candidate {
		var output: Candidate = value
		switch action {
			case .empty: return .init()
			case .join: return value
			case .ranked(let rank): output.rank += rank
			case .scope(let scope, let owner, let label):
				output = try store.enclosed(value, in: .fixed(scope))
				if let label {
					output.trees = try store.treeLists.single(
						store.branch(owner, label, value.trees, end)
					)
				}
			case .optional(let outer, let inner, let present):
				let body: Candidate =
					present
					? try store.enclosed(value, in: .fixed(inner)) : value
				return try store.enclosed(
					body,
					in: .fixed(outer),
					rank: present ? 1 : 0
				)
			case .leaf(let tree, let atom):
				return try .init(
					trees: store.treeLists.single(tree),
					atoms: store.atomLists.single(atom),
					selections: store.selectionLists.single(0)
				)
			case .committed(let trees, let atom):
				return try .init(
					trees: trees,
					atoms: store.atomLists.single(atom),
					selections: store.selectionLists.single(0)
				)
			case .relabel(let label):
				output.trees = 0
				var cursor: [Int] = [value.trees]
				while let id: Int = try store.treeLists.next(&cursor) {
					let old: DerivationStore.Tree = store.trees[id]
					let new: Int = try store.tree(
						.init(
							grammar: old.grammar,
							label: label,
							begin: old.begin,
							end: old.end,
							children: old.children
						)
					)
					output.trees = try store.treeLists.joined(
						output.trees,
						store.treeLists.single(new)
					)
				}
			case .iteration(_, _, _, let final):
				if final {
					return try store.finish(value.history, ending: .init())
				}
			case .stop(let expression, let state, let rank):
				let ending: Candidate = try store.enclosed(
					.init(),
					in: control(evaluation.loop(expression), state),
					rank: rank
				)
				return try store.finish(value.history, ending: ending)
			case .limit: return try store.finish(value.history, ending: .init())
		}
		return output
	}

}
