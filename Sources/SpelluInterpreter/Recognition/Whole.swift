import SpelluCore


// MARK: 全体一致の入口

extension Evaluation {

	/// 全体一致の入口の中の位置を進める。
	///
	/// 開始ルールを読み、開始ルールの文法の自動Triviaを読んでから、入力の終端を確かめる。
	/// 自動Triviaの失敗は記録せず、終端に届かなければ期待値 `.eos` を記録する。
	mutating func executeWhole(
		_ step: WholeStep,
		of rule: RuleID,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		switch step {
			case .rule:
				try call(
					.rule(rule),
					from: descriptor,
					mode: descriptor.call.mode,
					&session,
				)

			case .trivia:
				let grammar: GrammarID
				= session.table[rule].grammar

				guard
					session.table[grammar].hasTrivia
				else {
					try advance(
						descriptor,
						into: .whole(rule, .end),
						at: descriptor.position,
						environment: descriptor.environment,
						child: .nothing,
						&session,
					)

					return
				}

				try call(
					.trivia(grammar),
					from: descriptor,
					mode: .init(trivia: true, silent: true),
					&session,
				)

			case .end:
				guard
					descriptor.position == session.source.range.upperBound
				else {
					if !descriptor.call.mode.silent {
						session.record(descriptor.position, .value(.eos))
					}

					return
				}

				try complete(descriptor, &session)
		}
	}

}
