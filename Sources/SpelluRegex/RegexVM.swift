/// 明示的な再試行スタックを持つ、Scalar単位の専用VM。
@available(macOS 15, iOS 18, *)
struct RegexVM {

	enum Method { case whole, prefix, search }

	private struct Capture {
		var start: Int? = nil
		var range: Range<Int>? = nil
	}

	private struct Frame {
		var count: Int = 0
		var start: Int = 0
	}

	private struct State {
		var pc: Int = 0
		var position: Int
		var captures: [Capture]
		var loops: [Frame] = []
		var flags: RegexFlags
		var modifiers: [RegexFlags] = []
	}

	/// 先読みの外側の状態と、内部だけの再試行境界。
	private struct Lookahead {
		let outer: State
		let retryBase: Int
		let positive: Bool
		let resume: Int
	}

	let input: Substring
	let options: Options
	private let scalars: [UnicodeScalar]
	private let boundaries: [String.Index]
	private var steps: Int = 0

	init(
		input: Substring,
		options: Options,
	) throws {
		var scalars: [UnicodeScalar] = []
		var boundaries: [String.Index] = []
		var position: String.Index = input.startIndex
		while position < input.endIndex {
			guard scalars.count < options.limits.maximumInputScalars else {
				throw SpelluRegexError.resourceLimit("入力Scalar数")
			}
			boundaries.append(position)
			scalars.append(input.unicodeScalars[position])
			position = input.unicodeScalars.index(after: position)
		}
		boundaries.append(input.endIndex)
		self.input = input
		self.options = options
		self.scalars = scalars
		self.boundaries = boundaries
	}

	mutating func match(
		_ program: RegexProgram,
		method: Method,
	) throws -> Match? {
		let lastStart: Int = method == .search ? scalars.count : 0
		for start: Int in 0...lastStart {
			if let state: State = try run(
				program, start: start, whole: method == .whole,
			) {
				return .init(
					input: input,
					range: boundaries[start]..<boundaries[state.position],
					captures: state.captures.map { capture in
						capture.range.map {
							boundaries[$0.lowerBound]..<boundaries[$0.upperBound]
						}
					},
					namedCaptures: program.namedCaptures,
				)
			}
		}
		return nil
	}

	private mutating func run(
		_ program: RegexProgram,
		start: Int,
		whole: Bool,
	) throws -> State? {
		var state: State = .init(
			position: start,
			captures: .init(repeating: .init(), count: program.captureCount),
			flags: options.flags,
		)
		var retries: [State] = []
		var lookaheads: [Lookahead] = []
		while true {
			try spendStep()
			var succeeded: Bool = true
			switch program.code[state.pc] {
				case .accept:
					if !whole || state.position == scalars.count { return state }
					succeeded = false
				case let .character(character):
					if state.position < scalars.count,
						character.matches(
							scalars[state.position],
							options: options.applying(state.flags),
						) {
						state.position += 1
						state.pc += 1
					} else { succeeded = false }
				case let .assertion(start):
					succeeded = assertion(start, at: state.position, flags: state.flags)
					state.pc += 1
				case let .boundary(positive):
					let before: Bool = isWord(state.position - 1, flags: state.flags)
					let after: Bool = isWord(state.position, flags: state.flags)
					succeeded = (before != after) == positive
					state.pc += 1
				case let .reference(ids):
					if let range: Range<Int> = ids.lazy.compactMap({
						state.captures[$0].range
					}).first {
						succeeded = try reference(range, state: &state)
					}
					state.pc += 1
				case let .modifiersEnter(change):
					state.modifiers.append(state.flags)
					state.flags.formUnion(change.add)
					state.flags.subtract(change.remove)
					state.pc += 1
				case .modifiersLeave:
					state.flags = state.modifiers.removeLast()
					state.pc += 1
				case let .lookahead(positive, resume):
					try checkStack(retries.count, lookaheads: lookaheads.count)
					lookaheads.append(.init(
						outer: state, retryBase: retries.count,
						positive: positive, resume: resume,
					))
					state.pc += 1
				case .lookaheadEnd:
					let frame: Lookahead = lookaheads.removeLast()
					retries.removeSubrange(frame.retryBase...)
					let captures: [Capture] = state.captures
					state = frame.outer
					state.pc = frame.resume
					if frame.positive { state.captures = captures }
					else { succeeded = false }
				case let .split(first, next):
					var retry: State = state
					retry.pc = next
					try save(retry, into: &retries, lookaheads: lookaheads.count)
					state.pc = first
				case let .jump(next): state.pc = next
				case let .captureStart(id):
					state.captures[id] = .init(start: state.position)
					state.pc += 1
				case let .captureEnd(id):
					state.captures[id].range
						= state.captures[id].start!..<state.position
					state.pc += 1
				case .enter:
					state.loops.append(.init())
					state.pc += 1
				case let .decide(id):
					let loop: RegexProgram.Loop = program.loops[id]
					let count: Int = state.loops.last!.count
					if count < loop.quantifier.minimum {
						state.pc = loop.body
					} else if loop.quantifier.maximum.map({ count >= $0 }) == true {
						state.pc = loop.leave
					} else {
						var retry: State = state
						let greedy: Bool = loop.quantifier.greedy
						retry.pc = greedy ? loop.leave : loop.body
						try save(retry, into: &retries, lookaheads: lookaheads.count)
						state.pc = greedy ? loop.body : loop.leave
					}
				case let .iteration(id):
					state.loops[state.loops.count - 1].start = state.position
					for capture: Int in program.loops[id].captures {
						state.captures[capture] = .init()
					}
					state.pc += 1
				case let .next(id):
					let frame: Frame = state.loops.last!
					let loop: RegexProgram.Loop = program.loops[id]
					// 任意反復の空成功は失敗として巻き戻す。
					// 必須回数の空成功と、終了候補の捕捉を区別する。
					if frame.start == state.position,
						frame.count >= loop.quantifier.minimum {
						succeeded = false
					} else {
						state.loops[state.loops.count - 1].count += 1
						state.pc = loop.decide
					}
				case .leave:
					state.loops.removeLast()
					state.pc += 1
			}
			if !succeeded {
				guard resumeFailure(
					state: &state, retries: &retries, lookaheads: &lookaheads,
				) else { return nil }
			}
		}
	}

	/// 先読み内部を使い切ったら、外側を復元して肯定／否定を判定する。
	private func resumeFailure(
		state: inout State,
		retries: inout [State],
		lookaheads: inout [Lookahead],
	) -> Bool {
		while true {
			if let frame: Lookahead = lookaheads.last,
				retries.count == frame.retryBase {
				lookaheads.removeLast()
				state = frame.outer
				state.pc = frame.resume
				if !frame.positive { return true }
			} else {
				guard let retry: State = retries.popLast() else { return false }
				state = retry
				return true
			}
		}
	}

	private mutating func reference(
		_ range: Range<Int>,
		state: inout State,
	) throws -> Bool {
		guard range.count <= scalars.count - state.position else { return false }
		let effective: Options = options.applying(state.flags)
		for offset: Int in 0..<range.count {
			try spendStep()
			let character: RegexCharacter = .scalar(
				scalars[range.lowerBound + offset].value
			)
			guard character.matches(
				scalars[state.position + offset], options: effective,
			) else { return false }
		}
		state.position += range.count
		return true
	}

	private func isWord(_ position: Int, flags: RegexFlags) -> Bool {
		guard position >= 0, position < scalars.count else { return false }
		return RegexCharacter.shorthand(119, inverted: false).matches(
			scalars[position], options: options.applying(flags),
		)
	}

	private mutating func spendStep() throws {
		guard steps < options.limits.maximumSteps else {
			throw SpelluRegexError.resourceLimit("VM実行ステップ数")
		}
		steps += 1
	}

	private func save(
		_ state: State,
		into retries: inout [State],
		lookaheads: Int,
	) throws {
		try checkStack(retries.count, lookaheads: lookaheads)
		retries.append(state)
	}

	private func checkStack(
		_ retries: Int,
		lookaheads: Int,
	) throws {
		guard retries + lookaheads < options.limits.maximumBacktracking else {
			throw SpelluRegexError.resourceLimit("再試行スタック")
		}
	}

	private func assertion(
		_ start: Bool,
		at position: Int,
		flags: RegexFlags,
	) -> Bool {
		if start {
			return position == 0 || flags.contains(.multiline) && position > 0
				&& RegexCharacter.isLine(scalars[position - 1].value)
		}
		return position == scalars.count || flags.contains(.multiline)
			&& position < scalars.count
			&& RegexCharacter.isLine(scalars[position].value)
	}

}
