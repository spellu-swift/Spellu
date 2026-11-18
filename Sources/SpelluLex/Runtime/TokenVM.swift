import Basis
import UnicodeCaseFolding


/// Momojiri
/// 
/// 入力インターフェースを介してコンパイル済みProgramを評価する。
package struct TokenVM {

	package private(set) var stream: TokenInputStream
	package let maxRepetition: Int
	private var pc: Int = 0
	private var retries: [Retry] = []
	private var contexts: [Context] = []
	private var root: Int? = nil

	package init(
		stream: TokenInputStream,
		maxRepetition: Int,
	) {
		self.stream = stream
		self.maxRepetition = min(max(0, maxRepetition), Int.max - 1)
	}

	/// 失敗時はカーソルを開始位置に戻し、最遠失敗位置を返す。
	package mutating func match(
		_ program: TokenProgram,
	) -> TokenMatchResult {
		stream.resetFailure()
		reset()
		defer { reset() }

		let start: String.Index
		= stream.cursor

		while true {
			let matched: Bool
			switch program.code[pc] {
				case .accept:
					return .success(stream.cursor)
				case .fail:
					matched = false
				case let .requireLimit(minimum):
					matched = minimum <= maxRepetition
					pc += 1
				case let .matchClass(id):
					matched = matchClass(program.predicates[id])
					pc += 1
				case let .matchLiteral(id):
					matched = matchLiteral(program.literals[id])
					pc += 1
				case let .split(first, retry):
					save(.instruction(retry))
					pc = first
					matched = true
				case let .jump(target):
					pc = target
					matched = true
				case let .repeatEnter(id):
					enterLoop(id, program: program)
					matched = true
				case let .repeatDecide(id):
					decideLoop(id, program: program)
					matched = true
				case .repeatBody:
					var frame: RepeatFrame = currentRepeat
					frame.start = stream.cursor
					replaceRepeat(frame)
					pc += 1
					matched = true
				case let .repeatNext(id):
					finishIteration(id, program: program)
					matched = true
				case .repeatLeave:
					root = contexts[root!].parent
					pc += 1
					matched = true
				case let .repeatAtom(atom, repetition):
					matched = repeatAtom(
						atom, repetition: program.repetitions[repetition],
						program: program,
					)
				case .atomicEnter:
					enterAtomic()
					matched = true
				case .atomicLeave:
					leaveAtomic()
					matched = true
			}
			if !matched {
				stream.recordFailure()
				if !resume(program) {
					stream.cursor = start
					return .failure(stream.farthestFailure)
				}
			}
		}
	}

}


private extension TokenVM {

	struct RepeatFrame {
		var count: Int
		let maximum: Int
		var start: String.Index
	}

	struct AtomicFrame {
		let retryBase: Int
		let arenaBase: Int
	}

	enum Payload {
		case repetition(RepeatFrame)
		case atomic(AtomicFrame)
	}

	struct Context {
		let parent: Int?
		let payload: Payload
	}

	enum Resume {
		case instruction(Int)
		case eagerAtom(
			atom: Int, minimum: Int, count: Int, next: Int,
		)
		case reluctantAtom(
			atom: Int, maximum: Int, count: Int, next: Int,
		)
	}

	struct Retry {
		let resume: Resume
		let cursor: String.Index
		let root: Int?
		let arenaCount: Int
	}

	mutating func reset() {
		pc = 0
		root = nil
		retries.removeAll(keepingCapacity: true)
		contexts.removeAll(keepingCapacity: true)
	}

	mutating func save(
		_ resume: Resume,
		at cursor: String.Index? = nil,
	) {
		retries.append(.init(
			resume: resume,
			cursor: cursor ?? stream.cursor,
			root: root,
			arenaCount: contexts.count,
		))
	}

	mutating func resume(
		_ program: TokenProgram,
	) -> Bool {
		while let retry: Retry = retries.popLast() {
			stream.cursor = retry.cursor
			root = retry.root
			contexts.removeSubrange(retry.arenaCount...)
			switch retry.resume {
				case let .instruction(target):
					pc = target
					return true
				case let .eagerAtom(atom, minimum, count, next):
					saveShorterAtom(
						atom, minimum: minimum, count: count,
						next: next, program: program,
					)
					pc = next
					return true
				case let .reluctantAtom(atom, maximum, count, next):
					guard matchAtom(program.atoms[atom], program: program)
					else { continue }
					saveLongerAtom(
						atom, maximum: maximum, count: count + 1, next: next,
					)
					pc = next
					return true
			}
		}
		return false
	}

	mutating func push(
		_ payload: Payload,
		parent: Int?,
	) {
		contexts.append(.init(parent: parent, payload: payload))
		root = contexts.count - 1
	}

	var currentRepeat: RepeatFrame {
		guard case let .repetition(frame) = contexts[root!].payload
		else { preconditionFailure("反復Frameが必要です") }
		return frame
	}

	mutating func replaceRepeat(
		_ frame: RepeatFrame,
	) {
		// 保存済み候補のFrameは変更せず、新しい値を別ノードへ置く。
		let parent: Int? = contexts[root!].parent
		push(.repetition(frame), parent: parent)
	}

}


private extension TokenVM {

	mutating func enterLoop(
		_ id: Int,
		program: TokenProgram,
	) {
		let spec: TokenProgram.Repetition
		= program.repetitions[program.loops[id].repetition]
		push(.repetition(.init(
			count: 0,
			maximum: min(spec.maximum ?? maxRepetition,
				maxRepetition),
			start: stream.cursor,
		)), parent: root)
		pc += 1
	}

	mutating func decideLoop(
		_ id: Int,
		program: TokenProgram,
	) {
		let loop: TokenProgram.Loop = program.loops[id]
		let spec: TokenProgram.Repetition = program.repetitions[loop.repetition]
		let frame: RepeatFrame = currentRepeat
		if frame.count < spec.minimum {
			pc = loop.body
		}
		else if frame.count >= frame.maximum {
			pc = loop.leave
		}
		else if spec.behavior == .reluctant {
			save(.instruction(loop.body))
			pc = loop.leave
		}
		else {
			save(.instruction(loop.leave))
			pc = loop.body
		}
	}

	mutating func finishIteration(
		_ id: Int,
		program: TokenProgram,
	) {
		let loop: TokenProgram.Loop = program.loops[id]
		let minimum: Int = program.repetitions[loop.repetition].minimum
		var frame: RepeatFrame = currentRepeat
		frame.count += 1
		replaceRepeat(frame)
		pc = stream.cursor != frame.start || frame.count < minimum
			? loop.decide : loop.leave
	}

	mutating func enterAtomic() {
		let frame: AtomicFrame = .init(
			retryBase: retries.count, arenaBase: contexts.count,
		)
		push(.atomic(frame), parent: root)
		pc += 1
	}

	mutating func leaveAtomic() {
		let context: Context = contexts[root!]
		guard case let .atomic(frame) = context.payload
		else { preconditionFailure("確定範囲のFrameが必要です") }
		retries.removeSubrange(frame.retryBase...)
		root = context.parent
		contexts.removeSubrange(frame.arenaBase...)
		pc += 1
	}

}


private extension TokenVM {

	mutating func matchClass(
		_ predicate: TokenProgram.Predicate,
	) -> Bool {
		let start: String.Index = stream.cursor
		guard let scalar: UnicodeScalar = stream.scanNext() else {
			stream.recordFailure()
			return false
		}
		guard predicate.set.matches(
			scalar, caseInsensitive: predicate.caseInsensitive,
		) else {
			stream.recordFailure(at: start)
			stream.cursor = start
			return false
		}
		return true
	}

	mutating func matchLiteral(
		_ literal: TokenProgram.Literal,
	) -> Bool {
		switch literal {
			case let .exact(string, byteCount):
				return stream.match(
					string: string, byteCount: byteCount,
				).matchedEnd != nil
			case let .folded(scalars):
				let start: String.Index = stream.cursor
				for target: UInt32 in scalars {
					let position: String.Index = stream.cursor
					guard let scalar: UnicodeScalar = stream.scanNext(),
						UnicodeProperty.SimpleCaseFolding.folded(scalar.value)
						== target
					else {
						stream.recordFailure(at: position)
						stream.cursor = start
						return false
					}
				}
				return true
		}
	}

	mutating func matchAtom(
		_ atom: TokenProgram.Atom,
		program: TokenProgram,
	) -> Bool {
		switch atom {
			case let .character(id): matchClass(program.predicates[id])
			case let .literal(id): matchLiteral(program.literals[id])
		}
	}

	func previousAtomBoundary(
		_ atom: TokenProgram.Atom,
		program: TokenProgram,
	) -> String.Index {
		switch atom {
			case .character:
				return stream.input.unicodeScalars.index(before: stream.cursor)
			case let .literal(id):
				switch program.literals[id] {
					case let .exact(_, byteCount):
						return stream.input.utf8.index(
							stream.cursor, offsetBy: -byteCount,
						)
					case let .folded(scalars):
						// fold一致しても原文のUTF-8長は異なる場合がある。
						return stream.input.unicodeScalars.index(
							stream.cursor, offsetBy: -scalars.count,
						)
				}
		}
	}

}


private extension TokenVM {

	mutating func repeatAtom(
		_ atom: Int,
		repetition: TokenProgram.Repetition,
		program: TokenProgram,
	) -> Bool {
		let maximum: Int = min(
			repetition.maximum ?? maxRepetition,
			maxRepetition,
		)
		let target: Int = repetition.behavior == .reluctant
			? repetition.minimum : maximum
		var count: Int = 0
		while count < target,
			matchAtom(program.atoms[atom], program: program)
		{
			count += 1
		}
		guard count >= repetition.minimum else { return false }
		let next: Int = pc + 1
		switch repetition.behavior {
			case .eager:
				saveShorterAtom(
					atom, minimum: repetition.minimum, count: count,
					next: next, program: program,
				)
			case .reluctant:
				saveLongerAtom(
					atom, maximum: maximum, count: count, next: next,
				)
			case .possessive:
				break
		}
		pc = next
		return true
	}

	mutating func saveShorterAtom(
		_ atom: Int,
		minimum: Int,
		count: Int,
		next: Int,
		program: TokenProgram,
	) {
		guard count > minimum else { return }
		let previous: String.Index = previousAtomBoundary(
			program.atoms[atom], program: program,
		)
		save(.eagerAtom(
			atom: atom, minimum: minimum, count: count - 1, next: next,
		), at: previous)
	}

	mutating func saveLongerAtom(
		_ atom: Int,
		maximum: Int,
		count: Int,
		next: Int,
	) {
		guard count < maximum else { return }
		save(.reluctantAtom(
			atom: atom, maximum: maximum, count: count, next: next,
		))
	}

}
