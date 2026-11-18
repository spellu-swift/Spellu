/// VM専用の命令配列。構文の選択と照合時の再試行を分離する。
@available(macOS 15, iOS 18, *)
struct RegexProgram : Sendable {

	enum Instruction : Sendable {
		case character(RegexCharacter)
		case assertion(Bool)
		case boundary(Bool)
		case reference([Int])
		case lookahead(positive: Bool, resume: Int)
		case lookaheadEnd
		case modifiersEnter(RegexModifiers)
		case modifiersLeave
		case split(Int, Int)
		case jump(Int)
		case captureStart(Int)
		case captureEnd(Int)
		case enter(Int)
		case decide(Int)
		case iteration(Int)
		case next(Int)
		case leave
		case accept
	}

	struct Loop : Sendable {
		let quantifier: RegexQuantifier
		let captures: Range<Int>
		let decide: Int
		let body: Int
		var leave: Int
	}

	var code: [Instruction] = []
	var loops: [Loop] = []
	let captureCount: Int
	let namedCaptures: [RegexNamedCapture]

	private enum Task {
		case node(Int)
		case instruction(Instruction)
		case choice([Int], Int, [Int])
		case choiceNext([Int], Int, [Int], Int)
		case choiceEnd([Int])
		case loopEnd(Int)
		case lookaheadEnd(Int, Bool)
	}

	init(
		_ ast: RegexAST,
		limits: RegexLimits,
	) throws {
		captureCount = ast.captureCount
		namedCaptures = ast.namedCaptures
		var work: [Task] = [.instruction(.accept), .node(ast.root)]
		while let task: Task = work.popLast() {
			guard code.count < limits.maximumNodes else {
				throw SpelluRegexError.resourceLimit("VM命令数")
			}
			switch task {
				case let .instruction(instruction): code.append(instruction)
				case let .node(index):
					let node: RegexAST.Node = ast.nodes[index]
					switch node.kind {
						case let .character(value): code.append(.character(value))
						case let .assertion(start): code.append(.assertion(start))
						case let .boundary(positive): code.append(.boundary(positive))
						case let .reference(ids): code.append(.reference(ids))
						case let .lookahead(child, positive):
							let begin: Int = code.count
							code.append(.lookahead(positive: positive, resume: 0))
							work += [.lookaheadEnd(begin, positive), .node(child)]
						case let .modifiers(child, change):
							code.append(.modifiersEnter(change))
							work += [.instruction(.modifiersLeave), .node(child)]
						case let .sequence(children):
							work += children.reversed().map { .node($0) }
						case let .choice(children):
							work.append(.choice(children, 0, []))
						case let .capture(id, child):
							code.append(.captureStart(id))
							work += [.instruction(.captureEnd(id)), .node(child)]
						case let .repetition(child, quantifier):
							let id: Int = loops.count
							let start: Int = code.count
							loops.append(.init(
								quantifier: quantifier,
								captures: ast.nodes[child].captures,
								decide: start + 1, body: start + 2, leave: 0,
							))
							code += [.enter(id), .decide(id), .iteration(id)]
							work += [.loopEnd(id), .node(child)]
					}
				case let .choice(children, index, jumps):
					guard index < children.count else {
						work.append(.choiceEnd(jumps)); continue
					}
					if index == children.count - 1 {
						work += [.choiceEnd(jumps), .node(children[index])]
					} else {
						let split: Int = code.count
						code.append(.split(split + 1, 0))
						work += [
							.choiceNext(children, index, jumps, split),
							.node(children[index]),
						]
					}
				case let .choiceNext(children, index, jumps, split):
					let jump: Int = code.count
					code.append(.jump(0))
					code[split] = .split(split + 1, code.count)
					work.append(.choice(children, index + 1, jumps + [jump]))
				case let .choiceEnd(jumps):
					for jump: Int in jumps { code[jump] = .jump(code.count) }
				case let .lookaheadEnd(begin, positive):
					code.append(.lookaheadEnd)
					code[begin] = .lookahead(positive: positive, resume: code.count)
				case let .loopEnd(id):
					code.append(.next(id))
					loops[id].leave = code.count
					code.append(.leave)
			}
		}
	}

}
