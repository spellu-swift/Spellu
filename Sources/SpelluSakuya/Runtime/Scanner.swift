import Basis
import SpelluCore
import SpelluLex

extension Evaluation {

	func scan(_ cell: Int, _ id: LexemeID, owner: GrammarID) throws {
		let lexeme: GrammarModel.Lexeme = session.model.lexemes[id.index]
		let state: InputState = cells[cell].key.input
		let stream: SourceStream = session.input(state.position)
		switch stream.match(session.model.programs[lexeme.program.index]) {
			case .failure(let index):
				let offset: Int = stream.offset(of: index)
				record(
					cell,
					offset,
					lexeme.words == nil
						? .token(id, state.position, offset) : .words(id)
				)
			case .success(let index):
				let end: Int = stream.offset(of: index)
				if let words: [String] = lexeme.words {
					let text: String = String(
						session.source.content[utf8: state.position..<end]
					)
					let accepted: Bool =
						lexeme.insensitive
						? words.contains { $0.equalsIgnoringCase(text) }
						: words.contains(text)
					guard accepted else {
						record(cell, end, .words(id))
						return
					}
				}
				var output: InputState = state.moved(to: end)
				if let tag: String = lexeme.tag {
					output.environment = try session.capture(
						state.position..<end,
						tag: tag,
						owner: owner,
						state: state
					)
				}
				let tree: Int = try session.store.tree(
					.init(
						grammar: owner,
						label: lexeme.label,
						begin: state.position,
						end: end,
						children: 0
					)
				)
				try publish(
					cell,
					output,
					.init(action: .leaf(tree, .model(lexeme.atom)))
				)
		}
	}

	func scanReference(
		_ cell: Int,
		_ tag: String,
		_ spacious: Bool,
		_ atom: AtomID,
		_ owner: GrammarID
	) throws {
		let state: InputState = cells[cell].key.input
		guard
			let range: Range<Int> = session.captured(
				tag,
				owner: owner,
				state: state
			)
		else {
			record(cell, state.position)
			return
		}
		let text: String = String(session.source.content[utf8: range])
		guard let end: Int = session.input(state.position).matchReference(text)
		else {
			record(cell, state.position, .value(.literal(text)))
			return
		}
		let tree: Int = try session.store.tree(
			.init(
				grammar: owner,
				label: .none,
				begin: state.position,
				end: end,
				children: 0
			)
		)
		try publish(
			cell,
			state.moved(to: end),
			.init(action: .leaf(tree, .model(atom)))
		)
	}

	func scanTrivia(_ cell: Int, _ owner: GrammarID) throws {
		let plan: GrammarModel.TriviaPlan = session.model.grammars[owner.index]
			.trivia
		let state: InputState = cells[cell].key.input
		let stream: SourceStream = session.input(state.position)
		var end: Int = state.position
		if plan.hasLexical {
			if case .success(let position) = stream.match(
				session.model.programs[plan.optional.index]
			) {
				end = stream.offset(of: position)
			}
			if !cells[cell].key.mode.silent,
				case .failure(let position) = stream.match(
					session.model.programs[plan.required.index]
				)
			{
				record(cell, stream.offset(of: position), .value(.trivia))
			}
		}
		let reached: InputState = state.moved(to: end)
		try publish(cell, reached, .init(action: .empty))
		for expression: ExprID in plan.syntax {
			try request(
				.expression(expression),
				at: reached,
				from: cell,
				then: .triviaSyntax(cell, owner, end)
			)
		}
	}

}
