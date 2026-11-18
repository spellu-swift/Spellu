import Basis
import SpelluCore
import SpelluLex

/// SyntaxIRを読む処理をモデル生成へ閉じ込める。
struct ModelBuilder {

	private struct Declaration {
		let grammar: GrammarID
		let rule: SpelluRule
		let scope: ScopeID
	}

	private enum Assembly {
		case sequence
		case group(Label, ScopeID)
		case choice([Int])
		case optional(ScopeID, ScopeID)
		case repetition(Amount, SyntaxRepetitionBehavior)
		case list(Amount, Acceptance)
		case enclosure(Amount, SyntaxRepetitionBehavior, Bool)
		case capture
		case atomic(ScopeID, Bool)
		case relabel(Label)
	}

	private enum BuildTask {
		case syntax(SyntaxIR, GrammarID)
		case sequence([SyntaxIR], GrammarID)
		case assemble(Assembly, GrammarID, Int)
	}

	private var sources: [SpelluGrammar] = []
	private var names: [String: GrammarID] = [:]
	private var declarations: [Declaration] = []
	private var ruleNames: [[String: RuleID]] = []
	private var expressions: [GrammarModel.Expression] = []
	private var lexemes: [GrammarModel.Lexeme] = []
	private var programs: [TokenProgram] = []
	private var programIDs: [PatternKey: ProgramID] = [:]
	private var atoms: [GrammarModel.Atom: AtomID] = [:]
	private var scopeCount: Int = 0

	mutating func build(_ grammars: [SpelluGrammar]) throws -> GrammarModel {
		for grammar: SpelluGrammar in grammars {
			guard names[grammar.name] == nil else {
				throw SpelluError.duplicateGrammar(grammar: grammar.name)
			}
			_ = try register(grammar)
		}
		// 埋め込みの_ruleも先に収集し、相互参照の番号を確定する。
		var scanned: Int = 0
		while scanned < sources.count {
			let grammar: SpelluGrammar = sources[scanned]
			var pending: [SyntaxIR] = grammar.rules.flatMap(\.syntax.ir)
			for rule: String in grammar.trivia {
				pending.append(.ruleref(nil, rule))
			}
			while let ir: SyntaxIR = pending.popLast() {
				switch ir {
					case .sequence(_, let body), .optional(let body),
						.choiceOf(let body), .capture(let body),
						.atomic(let body),
						.repeat(let body, _, _):
						pending.append(contentsOf: body)
					case .anyOf(let branches):
						pending.append(contentsOf: branches.flatMap(\.body))
					case .list(let body, let separator, _, _):
						pending.append(contentsOf: body + separator)
					case .enclosure(let body, _, _, let opener, let closer):
						pending.append(contentsOf: body + opener + closer)
					case .relabel(_, let child): pending.append(child)
					default: break
				}
			}
			scanned += 1
		}
		var rules: [GrammarModel.Rule] = []
		for declaration: Declaration in declarations {
			let rule: SpelluRule = declaration.rule
			let body: ExprID = try compile(
				rule.syntax.ir,
				in: declaration.grammar
			)
			rules.append(
				.init(
					grammar: declaration.grammar,
					name: rule.name,
					label: rule.label.ensure(rule.name),
					exposed: rule.expose,
					scope: declaration.scope,
					body: body
				)
			)
		}
		var owners: [GrammarModel.Grammar] = []
		for index: Int in sources.indices {
			let source: SpelluGrammar = sources[index]
			let owner: GrammarID = .init(index: index)
			let trivia: GrammarModel.TriviaPlan = try trivia(source, owner)
			let entry: RuleID? = source.rules.first(where: \.expose).flatMap {
				ruleNames[index][$0.name]
			}
			owners.append(
				.init(
					name: source.name,
					rules: ruleNames[index],
					entry: entry,
					trivia: trivia
				)
			)
		}
		return .init(
			grammars: owners,
			rules: rules,
			expressions: expressions,
			lexemes: lexemes,
			programs: programs,
			grammarNames: names
		)
	}

	private mutating func register(_ grammar: SpelluGrammar) throws -> GrammarID
	{
		if let id: GrammarID = names[grammar.name] {
			return id
		}
		try validate(grammar)
		let id: GrammarID = .init(index: sources.count)
		names[grammar.name] = id
		sources.append(grammar)
		ruleNames.append([:])
		for rule: SpelluRule in grammar.rules {
			guard ruleNames[id.index][rule.name] == nil else {
				throw SpelluError.duplicateRule(
					grammar: grammar.name,
					rule: rule.name
				)
			}
			append(rule, to: id)
		}
		return id
	}

	private mutating func append(_ rule: SpelluRule, to owner: GrammarID) {
		ruleNames[owner.index][rule.name] = .init(index: declarations.count)
		declarations.append(.init(grammar: owner, rule: rule, scope: scope()))
	}

	private mutating func scope() -> ScopeID {
		defer { scopeCount += 1 }
		return .init(index: scopeCount)
	}

	private mutating func atom(_ value: GrammarModel.Atom) -> AtomID {
		if let id: AtomID = atoms[value] {
			return id
		}
		let id: AtomID = .init(index: atoms.count)
		atoms[value] = id
		return id
	}

	private mutating func program(_ pattern: TokenIR) -> ProgramID {
		let key: PatternKey = .init(pattern)
		if let id: ProgramID = programIDs[key] {
			return id
		}
		let id: ProgramID = .init(index: programs.count)
		programs.append(TokenProgramCompiler().compile(pattern))
		programIDs[key] = id
		return id
	}

	private mutating func insert(_ kind: GrammarModel.Kind, _ owner: GrammarID)
		-> ExprID
	{
		let id: ExprID = .init(index: expressions.count)
		expressions.append(.init(grammar: owner, kind: kind))
		return id
	}

	private func reference(_ name: String?, _ rule: String, _ owner: GrammarID)
		throws -> RuleID
	{
		let grammarName: String = name ?? sources[owner.index].name
		guard let target: GrammarID = names[grammarName] else {
			throw SpelluError.grammarNotFound(grammar: grammarName)
		}
		guard let id: RuleID = ruleNames[target.index][rule] else {
			throw SpelluError.ruleNotFound(grammar: grammarName, rule: rule)
		}
		if target != owner && !declarations[id.index].rule.expose {
			throw SpelluError.ruleNotFound(grammar: grammarName, rule: rule)
		}
		return id
	}

	private mutating func compile(_ syntax: [SyntaxIR], in owner: GrammarID)
		throws -> ExprID
	{
		var tasks: [BuildTask] = [.sequence(syntax, owner)]
		var values: [ExprID] = []
		while let task: BuildTask = tasks.popLast() {
			switch task {
				case .sequence(let body, let grammar):
					tasks.append(.assemble(.sequence, grammar, body.count))
					tasks.append(
						contentsOf: body.reversed().map { .syntax($0, grammar) }
					)
				case .assemble(let operation, let grammar, let count):
					let children: [ExprID] = Array(values.suffix(count))
					values.removeLast(count)
					values.append(assemble(operation, children, grammar))
				case .syntax(let ir, let grammar):
					var operation: Assembly
					var children: [[SyntaxIR]]
					switch ir {
						case .token(
							let label,
							let pattern,
							let spacious,
							let tag,
						):
							values.append(
								lexeme(
									pattern,
									label,
									spacious,
									tag,
									nil,
									false,
									grammar
								)
							)
							continue
						case .word(
							let label,
							let pattern,
							let words,
							let insensitive,
						):
							values.append(
								lexeme(
									pattern,
									label,
									true,
									nil,
									Array(Set(words)).sorted(),
									insensitive,
									grammar
								)
							)
							continue
						case .tokenref(let tag, let spacious):
							let identity: AtomID = atom(
								.reference(grammar, tag, spacious)
							)
							values.append(
								insert(
									.tokenReference(tag, spacious, identity),
									grammar
								)
							)
							continue
						case .ruleref(let name, let rule):
							values.append(
								insert(
									.reference(
										try reference(name, rule, grammar)
									),
									grammar
								)
							)
							continue
						case .trivia:
							values.append(insert(.trivia, grammar))
							continue
						case .sequence(let label, let body):
							operation = .group(label.ensure("#and"), scope())
							children = [body]
						case .choiceOf(let body):
							operation = .choice(
								body.indices.map { body.count - $0 - 1 }
							)
							children = body.map { [$0] }
						case .anyOf(let branches):
							operation = .choice(
								branches.map(\.precedence.rawValue)
							)
							children = branches.map(\.body)
						case .optional(let body):
							operation = .optional(scope(), scope())
							children = [body]
						case .repeat(let body, let amount, let behavior):
							operation = .repetition(amount, behavior)
							children = [body]
						case .list(
							let body,
							let separator,
							let trailing,
							let amount
						):
							operation = .list(amount, trailing)
							children = [body, separator]
						case .enclosure(
							let body,
							let amount,
							let behavior,
							let opener,
							let closer
						):
							operation = .enclosure(
								amount,
								behavior,
								body.isEmpty
							)
							children = [opener, body, closer]
						case .capture(let body):
							operation = .capture
							children = [body]
						case .atomic(let body):
							operation = .atomic(scope(), false)
							children = [body]
						case .relabel(let label, let body):
							operation = .relabel(.init(label))
							children = [[body]]
					}
					tasks.append(.assemble(operation, grammar, children.count))
					tasks.append(
						contentsOf: children.reversed().map {
							.sequence($0, grammar)
						}
					)
			}
		}
		precondition(values.count == 1)
		return values[0]
	}

	private mutating func lexeme(
		_ pattern: TokenIR,
		_ label: Label,
		_ spacious: Bool,
		_ tag: String?,
		_ words: [String]?,
		_ insensitive: Bool,
		_ owner: GrammarID
	) -> ExprID {
		let identity: AtomID =
			label == .none
			? atom(.lexical(PatternKey(pattern), spacious, words, insensitive))
			: atom(.position(scope()))
		let id: LexemeID = .init(index: lexemes.count)
		lexemes.append(
			.init(
				program: program(pattern),
				pattern: pattern,
				label: label,
				spacious: spacious,
				tag: tag,
				words: words,
				insensitive: insensitive,
				atom: identity
			)
		)
		return insert(.lexical(id), owner)
	}

	private mutating func loop(
		_ body: ExprID,
		_ amount: Amount,
		_ behavior: SyntaxRepetitionBehavior
	) -> GrammarModel.LoopPlan {
		.init(
			body: body,
			minimum: amount.min,
			maximum: amount.max,
			behavior: behavior,
			scope: scope(),
			bodyScope: scope(),
			control: scope()
		)
	}

	private mutating func assemble(
		_ operation: Assembly,
		_ children: [ExprID],
		_ owner: GrammarID
	) -> ExprID {
		let kind: GrammarModel.Kind
		switch operation {
			case .sequence:
				if children.count == 1 {
					return children[0]
				}
				kind = children.isEmpty ? .empty : .sequence(children)
			case .group(let label, let scope):
				kind = .group(children[0], scope, label)
			case .choice(let ranks):
				kind = .choice(
					zip(children, ranks).map { .init(body: $0, rank: $1) }
				)
			case .optional(let outer, let inner):
				kind = .optional(children[0], outer, inner)
			case .repetition(let amount, let behavior):
				kind = .repetition(loop(children[0], amount, behavior))
			case .list(let amount, let trailing):
				let pair: ExprID = insert(
					.sequence([children[1], children[0]]),
					owner
				)
				let maximum: Int? = amount.max.map { Swift.max($0 - 1, 0) }
				let restAmount: Amount =
					maximum.map { .range(Swift.max(amount.min - 1, 0), $0) }
					?? .nOrMore(Swift.max(amount.min - 1, 0))
				let rest: ExprID = insert(
					.repetition(loop(pair, restAmount, .eager)),
					owner
				)
				kind = .list(
					.init(
						body: children[0],
						separator: children[1],
						rest: rest,
						minimum: amount.min,
						maximum: amount.max,
						trailing: trailing,
						scope: scope()
					)
				)
			case .enclosure(let amount, let behavior, let empty):
				var parts: [ExprID] = [children[0]]
				if !empty {
					parts.append(
						insert(
							.repetition(loop(children[1], amount, behavior)),
							owner
						)
					)
				}
				parts.append(children[2])
				kind = .sequence(parts)
			case .capture: kind = .capture(children[0])
			case .atomic(let scope, let probe):
				kind = .atomic(children[0], scope, probe: probe)
			case .relabel(let label): kind = .relabel(children[0], label)
		}
		return insert(kind, owner)
	}

	private mutating func trivia(_ source: SpelluGrammar, _ owner: GrammarID)
		throws -> GrammarModel.TriviaPlan
	{
		var patterns: [TokenIR] = []
		for item: SpacePattern in source.spaces {
			switch item {
				case .space:
					patterns.append(.character(.include(.space)))
				case .newline: patterns.append(.character(.include(.newline)))
				case .character(let value):
					patterns.append(.character(value.set))
				case .string(let value): patterns.append(.string(value))
				case .token(let value): patterns.append(value)
			}
		}

		var syntax: [ExprID] = []
		for item: String in source.trivia {
			syntax.append(try compile([.ruleref(nil, item)], in: owner))
		}

		return .init(
			optional: program(.alternative(patterns, amount: .zeroOrMore)),
			required: program(.alternative(patterns, amount: .oneOrMore)),
			hasLexical: !patterns.isEmpty,
			syntax: syntax
		)
	}

}
