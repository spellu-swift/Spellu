import Basis
import UnicodeCaseFolding


/// TokenIRを再帰せずに走査し、ジャンプ先を解決する。
package struct TokenProgramCompiler {

	let optimizeSimpleRepetitions: Bool

	package init(
		optimizeSimpleRepetitions: Bool = true,
	) {
		self.optimizeSimpleRepetitions = optimizeSimpleRepetitions
	}

	package func compile(
		_ pattern: TokenIR,
	) -> TokenProgram {
		compile([pattern])
	}

	package func compile(
		_ patterns: [TokenIR],
	) -> TokenProgram {
		var builder: Builder = .init(
			optimizeSimpleRepetitions: optimizeSimpleRepetitions,
		)
		return builder.compile(patterns)
	}

}


private extension TokenProgramCompiler {

	enum Task {
		case pattern(TokenIR, Bool)
		case factor(TokenIR.Factor, Bool)
		case emit(TokenInstruction)
		case bind(Int)
	}

	struct Builder {
		let optimizeSimpleRepetitions: Bool
		var code: [TokenInstruction] = []
		var predicates: [TokenProgram.Predicate] = []
		var literals: [TokenProgram.Literal] = []
		var atoms: [TokenProgram.Atom] = []
		var repetitions: [TokenProgram.Repetition] = []
		var loops: [TokenProgram.Loop] = []
		var labels: [Int] = []
		var tasks: [Task] = []
	}

}


private extension TokenProgramCompiler.Builder {

	mutating func compile(
		_ patterns: [TokenIR],
	) -> TokenProgram {
		tasks = patterns.reversed().map { .pattern($0, false) }
		while let task: TokenProgramCompiler.Task = tasks.popLast() {
			switch task {
				case let .pattern(pattern, inherited):
					compilePattern(pattern, inherited: inherited)
				case let .factor(factor, ignoresCase):
					compileFactor(factor, ignoresCase: ignoresCase)
				case let .emit(instruction):
					code.append(instruction)
				case let .bind(label):
					labels[label] = code.count
			}
		}
		code.append(.accept)
		return .init(
			code: code.map(resolve),
			predicates: predicates,
			literals: literals,
			atoms: atoms,
			repetitions: repetitions,
			loops: loops.map { loop in
				.init(
					repetition: loop.repetition,
					decide: labels[loop.decide],
					body: labels[loop.body],
					leave: labels[loop.leave],
				)
			},
		)
	}

	mutating func compilePattern(
		_ pattern: TokenIR,
		inherited: Bool,
	) {
		let ignoresCase: Bool = pattern.caseInsensitive ?? inherited
		code.append(.requireLimit(pattern.amount.min))

		if pattern.amount != .exactly(1), optimizeSimpleRepetitions,
			let atom: TokenProgram.Atom
				= makeAtom(pattern.factor, ignoresCase: ignoresCase)
		{
			let atomId: Int = atoms.count
			atoms.append(atom)
			let repetitionId: Int = addRepetition(pattern)
			code.append(.repeatAtom(atom: atomId, repetition: repetitionId))
			return
		}

		if pattern.behavior == .possessive {
			code.append(.atomicEnter)
			tasks.append(.emit(.atomicLeave))
		}
		if pattern.amount == .exactly(1) {
			tasks.append(.factor(pattern.factor, ignoresCase))
			return
		}

		let loopId: Int = loops.count
		let repetitionId: Int = addRepetition(pattern)
		let decide: Int = makeLabel()
		let body: Int = makeLabel()
		let leave: Int = makeLabel()
		loops.append(.init(
			repetition: repetitionId, decide: decide, body: body, leave: leave,
		))
		code.append(.repeatEnter(loopId))
		let sequence: [TokenProgramCompiler.Task] = [
			.bind(decide), .emit(.repeatDecide(loopId)),
			.bind(body), .emit(.repeatBody(loopId)),
			.factor(pattern.factor, ignoresCase),
			.emit(.repeatNext(loopId)),
			.bind(leave), .emit(.repeatLeave(loopId)),
		]
		tasks.append(contentsOf: sequence.reversed())
	}

	mutating func compileFactor(
		_ factor: TokenIR.Factor,
		ignoresCase: Bool,
	) {
		if let atom: TokenProgram.Atom
			= makeAtom(factor, ignoresCase: ignoresCase)
		{
			switch atom {
				case let .character(id): code.append(.matchClass(id))
				case let .literal(id): code.append(.matchLiteral(id))
			}
			return
		}
		switch factor {
			case .string:
				// 空文字列は入力を消費せず成功する。
				break
			case .character:
				code.append(.fail)
			case let .sequence(patterns):
				for pattern: TokenIR in patterns.reversed() {
					tasks.append(.pattern(pattern, ignoresCase))
				}
			case let .alternative(patterns):
				compileAlternative(patterns, ignoresCase: ignoresCase)
		}
	}

	mutating func compileAlternative(
		_ patterns: [TokenIR],
		ignoresCase: Bool,
	) {
		guard !patterns.isEmpty else {
			code.append(.fail)
			return
		}
		let end: Int = makeLabel()
		var sequence: [TokenProgramCompiler.Task] = []
		for (index, pattern) in patterns.enumerated() {
			if index < patterns.count - 1 {
				let first: Int = makeLabel()
				let retry: Int = makeLabel()
				sequence.append(.emit(.split(first: first, retry: retry)))
				sequence.append(.bind(first))
				sequence.append(.pattern(pattern, ignoresCase))
				sequence.append(.emit(.jump(end)))
				sequence.append(.bind(retry))
			}
			else {
				sequence.append(.pattern(pattern, ignoresCase))
			}
		}
		sequence.append(.bind(end))
		tasks.append(contentsOf: sequence.reversed())
	}

	mutating func makeAtom(
		_ factor: TokenIR.Factor,
		ignoresCase: Bool,
	) -> TokenProgram.Atom? {
		switch factor {
			case let .character(set):
				let id: Int = predicates.count
				predicates.append(.init(
					set: set, caseInsensitive: ignoresCase,
				))
				return .character(id)
			case let .string(string):
				guard !string.isEmpty else { return nil }
				let id: Int = literals.count
				if ignoresCase {
					literals.append(.folded(string.unicodeScalars.map {
						UnicodeProperty.SimpleCaseFolding.folded($0.value)
					}))
				}
				else {
					literals.append(.exact(string, byteCount: string.utf8.count))
				}
				return .literal(id)
			case .sequence, .alternative:
				return nil
		}
	}

	mutating func addRepetition(
		_ pattern: TokenIR,
	) -> Int {
		let id: Int = repetitions.count
		repetitions.append(.init(
			minimum: pattern.amount.min,
			maximum: pattern.amount.max,
			behavior: pattern.behavior,
		))
		return id
	}

	mutating func makeLabel() -> Int {
		labels.append(-1)
		return labels.count - 1
	}

	func resolve(
		_ instruction: TokenInstruction,
	) -> TokenInstruction {
		switch instruction {
			case let .split(first, retry):
				.split(first: labels[first], retry: labels[retry])
			case let .jump(target): .jump(labels[target])
			default: instruction
		}
	}

}
