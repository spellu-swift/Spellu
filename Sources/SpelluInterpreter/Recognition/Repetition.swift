import SpelluCore
import SpelluLex


// MARK: 反復の指定

extension CodeTable {

	/// Repeatの命令の回数と選好。
	func repetition(
		at location: Location,
	) throws -> (amount: Amount, behavior: SyntaxRepetitionBehavior) {
		guard
			case let .repeat(_, amount, behavior)? = instruction(at: location)
		else {
			throw SpelluError.internalError(
				"Repeat call must point to a repeat",
			)
		}

		return (amount, behavior)
	}

}


// MARK: Optional

extension Evaluation {

	/// Optionalの選択肢を進める。
	///
	/// 本文ありの選択肢は本文を呼び、戻ったら完了する。本文なしの選択肢はすぐに完了する。
	mutating func executeOptional(
		_ step: OptionalStep,
		at location: Location,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		switch step {
			case .body:
				try call(
					.optionalBody(location),
					from: descriptor,
					mode: descriptor.call.mode,
					&session,
				)

			case .afterBody, .skipped:
				try complete(descriptor, &session)
		}
	}

}


// MARK: Repeat

extension Evaluation {

	/// 反復の位置（本文を `count` 回読み終えた位置）を進める。
	///
	/// - 必須回数に届いていれば、ここで反復を終えられる。
	/// - 上限に届いていなければ、本文をもう一回読む。戻り先は `loopContinuation` で決める。
	mutating func executeLoop(
		_ count: Int,
		at location: Location,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		let amount: Amount
		= try session.table.repetition(at: location).amount

		if count >= amount.min {
			try complete(descriptor, &session)
		}

		if amount.max.map({ count < $0 }) ?? true {
			try call(
				.iteration(location),
				from: descriptor,
				mode: descriptor.call.mode,
				&session,
			)
		}
	}

	/// 本文の一回が戻ったときの戻り先。
	///
	/// - 入力を読んだ回：次の位置へ進む。上限のない反復は、必須回数を超えた回数を
	///   まとめて数え、スロットの数を有限にする。
	/// - 空の回で、まだ必須回数に届かない：次の位置へ進む。空の回が上限を超えたら止める。
	/// - 空の回で、必須回数に届く：この回を最後の回として反復を終える（`final`）。
	func loopContinuation(
		_ count: Int,
		at location: Location,
		empty: Bool,
		_ session: Session,
	) throws -> Slot {
		let amount: Amount
		= try session.table.repetition(at: location).amount

		let next: Int
		= count + 1

		guard
			empty
		else {
			if amount.max == nil {
				return .loop(location, count: Swift.min(next, amount.min))
			}

			return .loop(location, count: next)
		}

		if next >= amount.min {
			return .final(location, count: count)
		}

		guard
			next <= session.limits.maxEmptyRepetition
		else {
			throw SpelluError.safetyStop(
				.overLimitsOfRepetition(
					limits: session.limits.maxEmptyRepetition,
				),
			)
		}

		return .loop(location, count: next)
	}

}
