import Basis
import UnicodeCaseFolding


///
/// TokenIRを評価するインタプリタ
///
package struct TokenMatcher {

	package var stream: TokenInputStream
	package let maxRepetition: Int

	package init(
		stream: TokenInputStream,
		maxRepetition: Int,
	) {
		self.stream = stream
		self.maxRepetition = min(max(0, maxRepetition), Int.max - 1)
	}

	/// 失敗時はカーソルを開始位置に戻し、最遠失敗位置を返す。
	/// onFailureには、失敗した要素・要素の開始位置・失敗位置を渡す。
	package mutating func match(
		_ pattern: TokenIR,
		onFailure: ((TokenIR.Factor, String.Index, String.Index) -> Void)? = nil,
	) -> TokenMatchResult {
		stream.resetFailure()
		let start: String.Index = stream.cursor
		var tasks: [Task] = [
			.pattern(pattern, false),
		]
		var retries: [Retry] = []

		// 再帰の代わりに、実行待ち処理と再試行位置を明示的に保持する。
		while let task: Task = tasks.popLast() {
			let matched: Bool

			switch task {
				case let .pattern(pattern, inheritedCaseInsensitive):
					matched = begin(
						pattern,
						caseInsensitive: inheritedCaseInsensitive,
						tasks: &tasks,
						retries: &retries,
					)

				case let .factor(factor, caseInsensitive):
					matched = matchFactor(
						factor,
						caseInsensitive: caseInsensitive,
						tasks: &tasks,
						retries: &retries,
						onFailure: onFailure,
					)

				case let .repetition(repetition):
					schedule(repetition, tasks: &tasks, retries: &retries)
					matched = true

				case let .repeated(repetition, start):
					var next: Repetition = repetition
					next.count += 1
					// 空成功は必須回数を満たすまでに留め、無消費ループを防ぐ。
					if stream.cursor != start || next.count < next.minimum {
						tasks.append(.repetition(next))
					}
					matched = true

				case let .endPossessive(depth):
					// 反復内部の候補だけを破棄し、外側のChoiceOfは残す。
					retries.removeSubrange(depth...)
					matched = true
			}

			if !matched {
				stream.recordFailure()
				guard
					let retry: Retry = retries.popLast()
				else {
					stream.cursor = start
					return .failure(stream.farthestFailure)
				}

				tasks = retry.tasks
				stream.cursor = retry.cursor
			}
		}

		return .success(stream.cursor)
	}

}


private extension TokenMatcher {

	enum Task {
		case pattern(TokenIR, Bool)
		case factor(TokenIR.Factor, Bool)
		case repetition(Repetition)
		case repeated(Repetition, String.Index)
		case endPossessive(Int)
	}

	struct Retry {
		let cursor: String.Index
		let tasks: [Task]
	}

	struct Repetition {
		let factor: TokenIR.Factor
		let minimum: Int
		let maximum: Int
		let behavior: TokenRepetitionBehavior
		let caseInsensitive: Bool
		var count: Int = 0
	}

	func begin(
		_ pattern: TokenIR,
		caseInsensitive: Bool,
		tasks: inout [Task],
		retries: inout [Retry],
	) -> Bool {
		guard
			pattern.amount.min <= maxRepetition
		else { return false }

		let range: ClosedRange<Int>
		= pattern.amount.asRange(maxRepetition)
		let maximum: Int = min(range.upperBound, maxRepetition)
		let caseInsensitive: Bool = pattern.caseInsensitive ?? caseInsensitive

		if pattern.behavior == .possessive {
			tasks.append(.endPossessive(retries.count))
		}
		if range.lowerBound == 1 && maximum == 1 {
			tasks.append(.factor(pattern.factor, caseInsensitive))
		}
		else {
			tasks.append(.repetition(.init(
				factor: pattern.factor,
				minimum: range.lowerBound,
				maximum: maximum,
				behavior: pattern.behavior,
				caseInsensitive: caseInsensitive,
			)))
		}

		return true
	}

	func schedule(
		_ repetition: Repetition,
		tasks: inout [Task],
		retries: inout [Retry],
	) {
		guard
			repetition.count < repetition.maximum
		else { return }

		let iteration: [Task] = [
			.repeated(repetition, stream.cursor),
			.factor(repetition.factor, repetition.caseInsensitive),
		]
		if repetition.count < repetition.minimum {
			tasks.append(contentsOf: iteration)
		}
		else if repetition.behavior == .reluctant {
			// 先に後続を試し、失敗した場合だけ本体をもう一度読む。
			retries.append(.init(
				cursor: stream.cursor,
				tasks: tasks + iteration,
			))
		}
		else {
			// 先に本体を読み、失敗した場合は今回の試行を取り消す。
			retries.append(.init(cursor: stream.cursor, tasks: tasks))
			tasks.append(contentsOf: iteration)
		}
	}

	mutating func matchFactor(
		_ factor: TokenIR.Factor,
		caseInsensitive: Bool,
		tasks: inout [Task],
		retries: inout [Retry],
		onFailure: ((TokenIR.Factor, String.Index, String.Index) -> Void)?,
	) -> Bool {
		switch factor {
			case let .character(set):
				let start: String.Index = stream.cursor
				guard
					let scalar: UnicodeScalar = stream.scanNext()
				else {
					onFailure?(factor, start, start)
					return false
				}

				guard set.matches(scalar, caseInsensitive: caseInsensitive)
				else {
					stream.cursor = start
					onFailure?(factor, start, start)
					return false
				}
				return true

			case let .string(string):
				let start: String.Index = stream.cursor
				switch matchString(string, caseInsensitive: caseInsensitive) {
					case .success: return true
					case let .failure(position):
						onFailure?(factor, start, position)
						return false
				}

			case let .alternative(rules):
				guard
					let first: TokenIR = rules.first
				else { return false }

				// 後続も含めて再実行できるよう、残りの候補を逆順に積む。
				for rule: TokenIR in rules.dropFirst().reversed() {
					retries.append(.init(
						cursor: stream.cursor,
						tasks: tasks + [.pattern(rule, caseInsensitive)],
					))
				}

			tasks.append(.pattern(first, caseInsensitive))
			
			return true

			case let .sequence(rules):
				for rule: TokenIR in rules.reversed() {
					tasks.append(.pattern(rule, caseInsensitive))
				}

			return true
		}
	}

	mutating func matchString(
		_ string: String,
		caseInsensitive: Bool,
	) -> TokenMatchResult {
		guard !string.isEmpty else { return .success(stream.cursor) }

		if caseInsensitive {
			let start: String.Index = stream.cursor
			for target: UnicodeScalar in string.unicodeScalars {
				let position: String.Index = stream.cursor
				guard let scalar: UnicodeScalar = stream.scanNext(),
					UnicodeProperty.SimpleCaseFolding.folded(scalar.value)
					== UnicodeProperty.SimpleCaseFolding.folded(target.value)
				else {
					stream.recordFailure(at: position)
					stream.cursor = start
					return .failure(position)
				}
			}
		}
		else {
			return stream.match(
				string: string, byteCount: string.utf8.count,
			)
		}

		return .success(stream.cursor)
	}

}
