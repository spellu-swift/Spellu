import Basis
import SpelluCore


// MARK: 構文の選択肢

extension CodeTable {

	/// 呼び出した構文の、各選択肢の先頭のスロット。
	func alternatives(
		of construct: Construct,
	) -> [Slot] {
		switch construct {
			case let .rule(rule):
				[.code(.init(block: self[rule].body, pc: 0))]

			case let .whole(rule):
				[.whole(rule, .rule)]

			case let .sequence(location),
				let .optionalBody(location),
				let .iteration(location),
				let .enclosure(location),
				let .capture(location),
				let .relabel(location),
				let .atomicBody(location):
				[.code(.init(block: children[location]![0], pc: 0))]

			case let .choice(location), let .list(location):
				// 枝のない選択肢は子の命令列を持たない。
				(children[location] ?? []).map {
					.code(.init(block: $0, pc: 0))
				}

			case let .optional(location):
				[.optional(location, .body), .optional(location, .skipped)]

			case let .repeat(location):
				[.loop(location, count: 0)]

			case let .trivia(grammar):
				[.trivia(grammar, .lexical)]

			case let .syntaxTrivia(grammar, index):
				[.code(.init(block: self[grammar].syntaxTrivia[index], pc: 0))]
		}
	}

}


// MARK: 命令ごとの動作

extension Evaluation {

	/// 命令を一つ実行する。
	///
	/// 字句・Word・後方参照（spacious）は、文法がTriviaを持てば先に自動Triviaを読む。
	/// 戻ったら `afterTrivia` のスロットで命令の本体を実行する。
	/// Triviaの照合中は自動Triviaを挟まない。
	mutating func execute(
		_ instruction: SyntaxIR,
		at location: Location,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		let spacious: Bool

		switch instruction {
			case let .token(_, _, value, _), let .tokenref(_, value):
				spacious = value

			case .word:
				spacious = true

			default:
				spacious = false
		}

		let grammar: GrammarID
		= session.table.grammar(of: location)

		if spacious,
			!descriptor.call.mode.trivia,
			session.table[grammar].hasTrivia
		{
			try call(
				.trivia(grammar),
				from: descriptor,
				mode: .init(trivia: true, silent: true),
				&session,
			)

			return
		}

		try perform(instruction, at: location, descriptor, &session)
	}

	/// 命令の本体を実行する。成功すれば次の命令へ進め、失敗すれば何もしない。
	mutating func perform(
		_ instruction: SyntaxIR,
		at location: Location,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		let mode: Mode
		= descriptor.call.mode

		switch instruction {
			case let .token(_, pattern, _, tag):
				let scanned: Session.Scan
				= try session.scan(
					pattern,
					token: session.table.token(at: location),
					at: descriptor.position,
				)

				switch scanned {
					case let .matched(end):
						// tag付きの字句は、読んだ範囲をタグ環境に記録する。
						let grammar: GrammarID
						= session.table.grammar(of: location)

						let environment: Environment
						= tag.map {
							descriptor.environment.recording(
								descriptor.position..<end,
								as: .init(grammar: grammar, name: $0),
							)
						} ?? descriptor.environment

						try advance(
							descriptor,
							to: end,
							environment: environment,
							child: .token(
								location,
								begin: descriptor.position,
								end: end,
							),
							&session,
						)

					case let .failed(failure):
						if !mode.silent {
							session.record(
								failure,
								.token(
									pattern,
									start: descriptor.position,
									failed: failure,
								),
							)
						}
				}

			case let .word(_, pattern, words, caseInsensitive):
				let scanned: Session.Scan
				= try session.scan(
					pattern,
					token: session.table.token(at: location),
					at: descriptor.position,
				)

				guard
					case let .matched(end) = scanned,
					session.accepts(
						descriptor.position..<end,
						words: words,
						caseInsensitive: caseInsensitive,
					)
				else {
					if !mode.silent {
						session.record(scanned.position, .words(words))
					}

					return
				}

				try advance(
					descriptor,
					to: end,
					environment: descriptor.environment,
					child: .token(
						location,
						begin: descriptor.position,
						end: end,
					),
					&session,
				)

			case let .tokenref(tag, _):
				try reference(tag, at: location, descriptor, &session)

			case .trivia:
				// 明示Trivia。空なら失敗にする（`continuation` で判定する）。
				try call(
					.trivia(session.table.grammar(of: location)),
					from: descriptor,
					mode: .init(trivia: true, silent: mode.silent),
					&session,
				)

			case .sequence:
				try call(
					.sequence(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .choiceOf, .anyOf:
				try call(
					.choice(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .optional:
				try call(
					.optional(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .repeat:
				try call(
					.repeat(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .list:
				try call(
					.list(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .enclosure:
				try call(
					.enclosure(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .capture:
				try call(
					.capture(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .relabel:
				try call(
					.relabel(location),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .ruleref:
				let rule: RuleID
				= session.table.references[location]!

				try call(
					.rule(rule),
					from: descriptor,
					mode: mode,
					&session,
				)

			case .atomic:
				try boundary(
					.atomicBody(location),
					mode: mode,
					at: location,
					descriptor,
					&session,
				)

			default:
				// 文法の準備で未対応の構文を拒否しているので、ここへは来ない。
				throw SpelluError.internalError(
					"Interpreter cannot execute \(instruction)",
				)
		}
	}

	/// 後方参照。同じ文法のtagで記録した文字列と同じものを読む。
	/// 記録がなければ、期待値なしで失敗を記録する。
	private mutating func reference(
		_ tag: String,
		at location: Location,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		let silent: Bool
		= descriptor.call.mode.silent

		let key: TagKey
		= .init(grammar: session.table.grammar(of: location), name: tag)

		guard
			let range: Range<Int> = descriptor.environment.range(of: key)
		else {
			if !silent {
				session.record(descriptor.position)
			}

			return
		}

		let text: String
		= session.text(range)

		guard
			let end: Int = try session.matchReference(
				text,
				at: descriptor.position,
			)
		else {
			if !silent {
				session.record(descriptor.position, .value(.literal(text)))
			}

			return
		}

		try advance(
			descriptor,
			to: end,
			environment: descriptor.environment,
			child: .token(location, begin: descriptor.position, end: end),
			&session,
		)
	}

	/// 子の確定範囲。子で一つに確定した結果を、一つの字句のように扱って進める。
	///
	/// 結果がまだなければ評価を止めて求める（`Session` が子を評価して記録する）。
	/// 子が一致しなければ、この経路は止まる。親から子の別の候補へ戻ることはできない。
	private mutating func boundary(
		_ entry: Construct,
		mode: Mode,
		at location: Location,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		let call: Call
		= .init(
			construct: entry,
			position: descriptor.position,
			environment: descriptor.environment,
			mode: mode,
		)

		guard
			let outcome: Session.BoundaryOutcome = session.boundaryResults[call]
		else {
			requestBoundary(call)

			return
		}

		guard
			case let .matched(match) = outcome
		else { return }

		try advance(
			descriptor,
			to: match.end,
			environment: match.environment,
			child: .boundary(
				location,
				trees: match.trees,
				trivia: match.trivia,
			),
			&session,
		)
	}

}
