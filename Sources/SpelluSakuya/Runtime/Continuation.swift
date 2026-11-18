import SpelluCore

extension Evaluation {

	func deliver(_ continuation: Continuation, _ result: Int) throws {
		let reached: InputState = results[result].output
		switch continuation {
			case .emit(let parent, let action):
				try publish(
					parent,
					reached,
					.init(action: action, children: [result])
				)
			case .restore(let parent, let environment):
				try publish(
					parent,
					.init(position: reached.position, environment: environment),
					.init(action: .join, children: [result])
				)
			case .head(let parent, let expression, let next):
				try request(
					.sequence(expression, next),
					at: reached,
					from: parent,
					then: .tail(parent, result)
				)
			case .tail(let parent, let previous):
				try publish(
					parent,
					reached,
					.init(action: .join, children: [previous, result])
				)
			case .prepared(let parent, let expression):
				let continuation: Continuation
				if case .step = results[result].families[0].trivia {
					continuation = .preparedBody(parent, result)
				} else {
					continuation = .emit(parent, .join)
				}

				try request(
					.expression(expression, prepared: true),
					at: reached,
					from: parent,
					then: continuation
				)
			case .preparedBody(let parent, let trivia):
				try publish(
					parent,
					reached,
					.init(
						action: .join,
						children: [result],
						trivia: .beforeArrival(trivia)
					)
				)
			case .prefix(let root, let expression, let state):
				let plan: GrammarModel.LoopPlan = loop(expression)
				if state.count == plan.maximum {
					try publish(
						root,
						reached,
						.init(action: .limit, children: [result])
					)
					return
				}
				if state.count >= plan.minimum
					&& !rejectStop(expression, reached)
				{
					try publish(
						root,
						reached,
						.init(
							action: .stop(
								expression,
								state,
								plan.behavior == .eager ? 0 : 1
							),
							children: [result]
						)
					)
				}
				try request(
					.expression(plan.body),
					at: reached,
					from: root,
					then: .body(root, expression, state, result)
				)
			case .body(let root, let expression, let state, let previous):
				let plan: GrammarModel.LoopPlan = loop(expression)
				let empty: Bool =
					reached.position == results[previous].output.position
				let rank: Int =
					state.count < plan.minimum || plan.behavior == .reluctant
					? 0 : 1
				let finished: Bool = empty && state.count + 1 >= plan.minimum
				let family: Family = .init(
					action: .iteration(
						expression,
						state,
						rank,
						final: finished
					),
					children: [previous, result]
				)
				if finished {
					try publish(root, reached, family)
					return
				}
				let next: LoopState = .init(
					count: state.count + 1,
					emptyCount: empty ? state.emptyCount + 1 : 0
				)
				guard next.emptyCount < session.limits.maxSyntaxRepetition
				else {
					throw SpelluError.safetyStop(
						.overLimitsOfRepetition(
							limits: session.limits.maxSyntaxRepetition
						)
					)
				}
				try publish(prefix(root, expression, next), reached, family)
			case .first(let parent, let expression):
				let plan: GrammarModel.ListPlan = list(expression)
				try request(
					.expression(plan.rest),
					at: reached,
					from: parent,
					then: .rest(parent, expression, result)
				)
			case .rest(let parent, let expression, let first):
				let plan: GrammarModel.ListPlan = list(expression)
				let owner: GrammarID = session.model.expressions[
					expression.index
				].grammar
				try publish(
					parent,
					reached,
					.init(
						action: .scope(plan.scope, owner, nil),
						children: [first, result]
					)
				)
				if plan.trailing == .allow {
					try request(
						.expression(plan.separator),
						at: reached,
						from: parent,
						then: .separator(parent, expression, first, result)
					)
				}
			case .separator(let parent, let expression, let first, let rest):
				let plan: GrammarModel.ListPlan = list(expression)
				let owner: GrammarID = session.model.expressions[
					expression.index
				].grammar
				try publish(
					parent,
					reached,
					.init(
						action: .scope(plan.scope, owner, nil),
						children: [first, rest, result]
					)
				)
			case .triviaSyntax(let parent, let owner, let begin):
				if reached.position > begin {
					try request(
						.trivia(owner),
						at: reached,
						from: parent,
						then: .triviaRest(parent, owner, begin..<reached.position)
					)
				}
			case .triviaRest(let parent, let owner, let range):
				let trivia: TriviaContribution
				= collectsTrivia ? .step(owner, range, rest: result) : .none

				try publish(parent, reached, .init(action: .empty, trivia: trivia))
			case .requiredTrivia(let parent, let owner):
				let start: Int = cells[parent].key.input.position
				guard reached.position > start else {
					record(parent, reached.position, .value(.trivia))
					return
				}
				let tree: Int = try session.store.tree(
					.init(
						grammar: owner,
						label: "#spaces",
						begin: start,
						end: reached.position,
						children: 0
					)
				)
				try publish(
					parent,
					reached,
					.init(action: .leaf(tree, .trivia))
				)
			case .ending(let parent, let owner):
				try request(
					.eos(owner),
					at: reached,
					from: parent,
					then: .ended(parent, result)
				)
			case .ended(let parent, let rule):
				let trivia: TriviaContribution
				if case .beforeArrival(let arrival)
					= results[result].families[0].trivia
				{
					trivia = .afterArrival(arrival)
				} else {
					trivia = .none
				}

				try publish(
					parent, reached,
					.init(action: .join, children: [rule], trivia: trivia)
				)
			case .eos(let parent):
				let trivia: TriviaContribution
				if case .step = results[result].families[0].trivia {
					trivia = .beforeArrival(result)
				} else {
					trivia = .none
				}

				try end(parent, reached, trivia: trivia)
		}
	}

	private func list(_ id: ExprID) -> GrammarModel.ListPlan {
		guard case .list(let plan) = session.model.expressions[id.index].kind
		else { preconditionFailure() }
		return plan
	}

}
