import Basis
import SpelluCore
import SpelluLex


/// SyntaxIRを読む処理をモデル生成へ閉じ込める。
///
/// 入れ子の構文は補助の非終端記号にして、本体の変換を作業キューへ積む。
/// 構文の深さをSwiftの呼び出し深さへ変換しない。
struct ModelBuilder {

	typealias Symbol = GrammarModel.Symbol

	/// 同じ構文でも、Trivia照合中か診断を抑制するかで動作が変わる。
	struct Mode : Hashable {
		var trivia: Bool = false
		var silent: Bool = false
	}

	private struct Declaration {
		let grammar: Int32
		let rule: SpelluRule
		let scope: Int32
	}

	private struct RuleKey : Hashable {
		let rule: Int32
		let mode: Mode
	}

	private struct SkipKey : Hashable {
		let grammar: Int32
		let silent: Bool
	}

	private struct ClassKey : Hashable {
		let pattern: PatternKey
		let words: [String]?
		let insensitive: Bool
		let prefix: Int32
	}

	private struct TagKey : Hashable {
		let grammar: Int32
		let tag: String
	}

	private enum AtomKey : Hashable {
		case lexical(PatternKey, Bool, [String]?, Bool)
		case reference(Int32, String, Bool)
	}

	private struct TriviaPlan {
		let optional: Int32
		let required: Int32
		let hasLexical: Bool
		let syntax: [SyntaxIR]
	}

	private enum Task {
		case body(Int32, [SyntaxIR], Int32, Mode)
		case rule(Int32, Int32, Mode)
		case list(Int32, SyntaxIR, Int32, Mode)
		case skip(Int32, Int32, Bool)
	}

	private enum Pending {
		case syntax(SyntaxIR)
		case loop([SyntaxIR], Amount, SyntaxRepetitionBehavior)
	}

	private var sources: [SpelluGrammar] = []
	private var names: [String: Int32] = [:]
	private var declarations: [Declaration] = []
	private var ruleNames: [[String: Int32]] = []
	private var plans: [TriviaPlan] = []

	private var symbols: [Symbol] = []
	private var owners: [Int32] = []
	private var productions: [GrammarModel.Production] = []
	private var nonterminals: [GrammarModel.Nonterminal] = []
	private var lexemes: [GrammarModel.Lexeme] = []
	private var scanClasses: [GrammarModel.ScanClass] = []
	private var scanDetails: [GrammarModel.ScanDetail] = []
	private var references: [GrammarModel.Reference] = []
	private var points: [GrammarModel.Point] = []
	private var triviaScans: [GrammarModel.TriviaScan] = []
	private var boundaries: [GrammarModel.Boundary] = []
	private var programs: [TokenProgram] = []
	private var labels: [Label] = []
	private var tags: [String] = []

	private var programIDs: [PatternKey: Int32] = [:]
	private var classIDs: [ClassKey: Int32] = [:]
	private var labelIDs: [Label: Int32] = [:]
	private var tagIDs: [TagKey: Int32] = [:]
	private var atoms: [AtomKey: Int32] = [:]
	private var ruleNonterminals: [RuleKey: Int32] = [:]
	private var skips: [SkipKey: Int32] = [:]
	private var explicitTrivia: [SkipKey: Int32] = [:]
	private var triviaSites: [SkipKey: Int32] = [:]
	private var tasks: [Task] = []
	private var identityCount: Int32 = 0

	mutating func build(
		_ grammars: [SpelluGrammar],
	) throws -> GrammarModel {
		for grammar: SpelluGrammar in grammars {
			guard
				names[grammar.name] == nil
			else { throw SpelluError.duplicateGrammar(grammar: grammar.name) }

			_ = try register(grammar)
		}

		try collectEmbeddedRules()

		for index: Int in sources.indices {
			plans.append(plan(sources[index]))
		}

		let noneLabel: Int32
		= label(.none)

		let nilLabel: Int32
		= label("#nil")

		let triviaLabel: Int32
		= label("#spaces")

		let triviaAtom: Int32
		= identity()

		var rules: [GrammarModel.Rule] = []

		for index: Int in declarations.indices {
			let declaration: Declaration
			= declarations[index]

			let nonterminal: Int32
			= ruleNonterminal(Int32(index), mode: .init())

			let whole: Int32
			= wholeNonterminal(nonterminal, grammar: declaration.grammar)

			rules.append(
				.init(
					grammar: declaration.grammar,
					name: declaration.rule.name,
					exposed: declaration.rule.expose,
					nonterminal: nonterminal,
					whole: whole,
				),
			)
		}

		while let task: Task = tasks.popLast() {
			try run(task)
		}

		let productionOrder: [Int32]
		= linkProductions()

		var owned: [GrammarModel.Grammar] = []

		for index: Int in sources.indices {
			let source: SpelluGrammar
			= sources[index]

			owned.append(
				.init(
					name: source.name,
					rules: ruleNames[index],
					entry: source.rules.first(where: \.expose).flatMap {
						ruleNames[index][$0.name]
					},
				),
			)
		}

		return .init(
			symbols: symbols,
			owners: owners,
			productions: productions,
			productionOrder: productionOrder,
			nonterminals: nonterminals,
			lexemes: lexemes,
			scanClasses: scanClasses,
			scanDetails: scanDetails,
			references: references,
			points: points,
			triviaScans: triviaScans,
			boundaries: boundaries,
			programs: programs,
			labels: labels,
			noneLabel: noneLabel,
			nilLabel: nilLabel,
			triviaLabel: triviaLabel,
			triviaAtom: triviaAtom,
			tags: tags,
			rules: rules,
			grammars: owned,
			grammarNames: names,
		)
	}

}


// MARK: 文法の登録

extension ModelBuilder {

	private mutating func register(
		_ grammar: SpelluGrammar,
	) throws -> Int32 {
		if let id: Int32 = names[grammar.name] {
			return id
		}

		try validate(grammar)

		let id: Int32
		= Int32(sources.count)

		names[grammar.name] = id
		sources.append(grammar)
		ruleNames.append([:])

		for rule: SpelluRule in grammar.rules {
			guard
				ruleNames[Int(id)][rule.name] == nil
			else {
				throw SpelluError.duplicateRule(
					grammar: grammar.name,
					rule: rule.name,
				)
			}

			declare(rule, in: id)
		}

		return id
	}

	private mutating func declare(
		_ rule: SpelluRule,
		in owner: Int32,
	) {
		ruleNames[Int(owner)][rule.name] = Int32(declarations.count)
		declarations.append(
			.init(
				grammar: owner,
				rule: rule,
				scope: identity(),
			),
		)
	}

	/// 埋め込みの `_rule` も先に集め、相互参照の番号を確定する。
	private mutating func collectEmbeddedRules() throws {
		var scanned: Int = 0

		while scanned < sources.count {
			let grammar: SpelluGrammar
			= sources[scanned]

			var pending: [SyntaxIR]
			= grammar.rules.flatMap(\.syntax.ir)

			for rule: String in grammar.trivia {
				pending.append(.ruleref(nil, rule))
			}

			while let ir: SyntaxIR = pending.popLast() {
				switch ir {
					case .sequence(_, let body),
						.optional(let body),
						.choiceOf(let body),
						.capture(let body),
						.atomic(let body),
						.repeat(let body, _, _):
						pending.append(contentsOf: body)
					case .anyOf(let branches):
						pending.append(contentsOf: branches.flatMap(\.body))
					case .list(let body, let separator, _, _):
						pending.append(contentsOf: body + separator)
					case .enclosure(let body, _, _, let opener, let closer):
						pending.append(contentsOf: body + opener + closer)
					case .relabel(_, let child):
						pending.append(child)
					default:
						break
				}
			}

			scanned += 1
		}
	}

	private mutating func plan(
		_ source: SpelluGrammar,
	) -> TriviaPlan {
		var patterns: [TokenIR] = []
		var syntax: [SyntaxIR] = []

		for item: SpacePattern in source.spaces {
			switch item {
				case .space:
					patterns.append(.character(.include(.space)))
				case .newline:
					patterns.append(.character(.include(.newline)))
				case .character(let value):
					patterns.append(.character(value.set))
				case .string(let value):
					patterns.append(.string(value))
				case .token(let value):
					patterns.append(value)
			}
		}

		for item: String in source.trivia {
			syntax.append(.ruleref(nil, item))
		}

		return .init(
			optional: program(.alternative(patterns, amount: .zeroOrMore)),
			required: program(.alternative(patterns, amount: .oneOrMore)),
			hasLexical: !patterns.isEmpty,
			syntax: syntax,
		)
	}

	private func resolve(
		_ name: String?,
		_ rule: String,
		from owner: Int32,
	) throws -> Int32 {
		let grammarName: String
		= name ?? sources[Int(owner)].name

		guard
			let target: Int32 = names[grammarName]
		else { throw SpelluError.grammarNotFound(grammar: grammarName) }

		guard
			let id: Int32 = ruleNames[Int(target)][rule]
		else {
			throw SpelluError.ruleNotFound(
				grammar: grammarName,
				rule: rule,
			)
		}

		if target != owner && !declarations[Int(id)].rule.expose {
			throw SpelluError.ruleNotFound(
				grammar: grammarName,
				rule: rule,
			)
		}

		return id
	}

}


// MARK: 番号の割り当て

extension ModelBuilder {

	/// 比較範囲とAtomは同じ番号の空間を使う。範囲を閉じた子のAtomは範囲の番号になる。
	private mutating func identity() -> Int32 {
		defer { identityCount += 1 }

		return identityCount
	}

	private mutating func label(
		_ value: Label,
	) -> Int32 {
		if let id: Int32 = labelIDs[value] {
			return id
		}

		let id: Int32
		= Int32(labels.count)

		labels.append(value)
		labelIDs[value] = id

		return id
	}

	private mutating func program(
		_ pattern: TokenIR,
	) -> Int32 {
		let key: PatternKey
		= .init(pattern)

		if let id: Int32 = programIDs[key] {
			return id
		}

		let id: Int32
		= Int32(programs.count)

		programs.append(TokenProgramCompiler().compile(pattern))
		programIDs[key] = id

		return id
	}

	private mutating func tag(
		_ value: String,
		grammar: Int32,
	) -> Int32 {
		let key: TagKey
		= .init(grammar: grammar, tag: value)

		if let id: Int32 = tagIDs[key] {
			return id
		}

		let id: Int32
		= Int32(tags.count)

		tags.append(value)
		tagIDs[key] = id

		return id
	}

	private mutating func atom(
		_ key: AtomKey,
	) -> Int32 {
		if let id: Int32 = atoms[key] {
			return id
		}

		let id: Int32
		= identity()

		atoms[key] = id

		return id
	}

	private mutating func nonterminal(
		_ kind: GrammarModel.NonterminalKind,
		grammar: Int32,
	) -> Int32 {
		let id: Int32
		= Int32(nonterminals.count)

		nonterminals.append(.init(kind: kind, grammar: grammar))

		return id
	}

	private mutating func addProduction(
		_ lhs: Int32,
		_ body: [Symbol],
		rank: Int32 = 0,
		action: GrammarModel.ProductionAction = .join,
	) {
		let id: Int32
		= Int32(productions.count)

		productions.append(
			.init(
				lhs: lhs,
				first: Int32(symbols.count),
				rank: rank,
				action: action,
			),
		)
		symbols.append(contentsOf: body)
		symbols.append(.end(id))
		owners.append(
			contentsOf: repeatElement(id, count: body.count + 1),
		)
	}

}


// MARK: 非終端記号の生成

extension ModelBuilder {

	private mutating func ruleNonterminal(
		_ rule: Int32,
		mode: Mode,
	) -> Int32 {
		let key: RuleKey
		= .init(rule: rule, mode: mode)

		if let id: Int32 = ruleNonterminals[key] {
			return id
		}

		let declaration: Declaration
		= declarations[Int(rule)]

		let id: Int32
		= nonterminal(
			.scoped(
				scope: declaration.scope,
				label: label(
					declaration.rule.label.ensure(declaration.rule.name),
				),
			),
			grammar: declaration.grammar,
		)

		nonterminals[Int(id)].isRule = true
		ruleNonterminals[key] = id
		tasks.append(.rule(id, rule, mode))

		return id
	}

	/// 全体一致では、開始ルールの後に末尾Triviaと入力の終端を確認する。
	private mutating func wholeNonterminal(
		_ rule: Int32,
		grammar: Int32,
	) -> Int32 {
		let id: Int32
		= nonterminal(.whole, grammar: grammar)

		var body: [Symbol]
		= [.nonterminal(rule, .none)]

		appendTriviaPrefix(to: &body, grammar: grammar)
		body.append(.eos(silent: false))
		addProduction(id, body)

		return id
	}

	/// 自動Triviaを、字句以外の記号の前に置く。
	private mutating func appendTriviaPrefix(
		to output: inout [Symbol],
		grammar: Int32,
	) {
		let plan: TriviaPlan
		= plans[Int(grammar)]

		if !plan.syntax.isEmpty {
			output.append(
				.nonterminal(skip(grammar, silent: true), .none),
			)
		}
		else if plan.hasLexical {
			output.append(.trivia(triviaSite(grammar, silent: true)))
		}
	}

	private mutating func skip(
		_ grammar: Int32,
		silent: Bool,
	) -> Int32 {
		let key: SkipKey
		= .init(grammar: grammar, silent: silent)

		if let id: Int32 = skips[key] {
			return id
		}

		let id: Int32
		= nonterminal(.skip, grammar: grammar)

		skips[key] = id
		tasks.append(.skip(id, grammar, silent))

		return id
	}

	private mutating func triviaSite(
		_ grammar: Int32,
		silent: Bool,
	) -> Int32 {
		let key: SkipKey
		= .init(grammar: grammar, silent: silent)

		if let id: Int32 = triviaSites[key] {
			return id
		}

		let plan: TriviaPlan
		= plans[Int(grammar)]

		let id: Int32
		= Int32(triviaScans.count)

		triviaScans.append(
			.init(
				optional: plan.optional,
				required: plan.required,
				silent: silent,
			),
		)
		triviaSites[key] = id

		return id
	}

	private mutating func explicitTriviaNonterminal(
		_ grammar: Int32,
		silent: Bool,
	) -> Int32 {
		let key: SkipKey
		= .init(grammar: grammar, silent: silent)

		if let id: Int32 = explicitTrivia[key] {
			return id
		}

		let id: Int32
		= nonterminal(.explicitTrivia, grammar: grammar)

		explicitTrivia[key] = id
		addProduction(
			id,
			[
				.nonterminal(
					skip(grammar, silent: silent),
					.explicitTrivia(silent: silent),
				),
			],
		)

		return id
	}

	/// Atomicと内部の前方一致は、本体全体を子の確定範囲で評価する。
	private mutating func internalBoundary(
		_ body: [SyntaxIR],
		probe: Bool,
		grammar: Int32,
		mode: Mode,
	) -> Int32 {
		var inner: Mode
		= mode

		inner.silent = mode.silent || probe

		let scope: Int32
		= identity()

		let entry: Int32
		= nonterminal(
			.scoped(scope: scope, label: label("#atomic")),
			grammar: grammar,
		)

		tasks.append(.body(entry, body, grammar, inner))

		let id: Int32
		= Int32(boundaries.count)

		boundaries.append(
			.init(
				entry: entry,
				atom: scope,
				probe: probe,
			),
		)

		return id
	}

	/// 上限なしの部分は左再帰、必須回数と有限の上限は回数ごとの前半へ展開する。
	private mutating func loop(
		body: Int32,
		minimum: Int,
		maximum: Int?,
		behavior: SyntaxRepetitionBehavior,
		grammar: Int32,
	) -> Int32 {
		let exit: Int32
		= nonterminal(.loop(scope: identity()), grammar: grammar)

		let top: Int
		= maximum ?? minimum

		var prefixes: [Int32] = []
		var controls: [Int32] = []

		for _ in 0...top {
			prefixes.append(nonterminal(.loopPrefix, grammar: grammar))
			controls.append(identity())
		}

		func rank(
			_ count: Int,
		) -> Int32 {
			count < minimum || behavior == .reluctant ? 0 : 1
		}

		addProduction(prefixes[0], [])

		for count: Int in 0..<top {
			let condition: GrammarModel.SpanCondition
			= count + 1 >= minimum ? .nonEmpty : .required(Int32(count + 1))

			addProduction(
				prefixes[count + 1],
				[
					.nonterminal(prefixes[count], .none),
					.nonterminal(body, condition),
				],
				rank: rank(count),
				action: .iterate(control: controls[count]),
			)
		}

		if maximum == nil {
			addProduction(
				prefixes[top],
				[
					.nonterminal(prefixes[top], .none),
					.nonterminal(body, .nonEmpty),
				],
				rank: rank(top),
				action: .iterate(control: controls[top]),
			)
		}

		for count: Int in minimum...top {
			if count == maximum {
				addProduction(
					exit,
					[.nonterminal(prefixes[count], .none)],
					action: .limit,
				)
			}
			else {
				addProduction(
					exit,
					[.nonterminal(prefixes[count], .none)],
					rank: behavior == .eager ? 0 : 1,
					action: .stop(control: controls[count]),
				)
			}
		}

		for count: Int in Swift.max(minimum - 1, 0)...top
		where count != maximum {
			addProduction(
				exit,
				[
					.nonterminal(prefixes[count], .none),
					.nonterminal(body, .emptyOnly),
				],
				rank: rank(count),
				action: .final(control: controls[count]),
			)
		}

		return exit
	}

}


// MARK: 本体の変換

extension ModelBuilder {

	private mutating func run(
		_ task: Task,
	) throws {
		switch task {
			case let .body(id, body, grammar, mode):
				try addBody(id, body, grammar: grammar, mode: mode)

			case let .rule(id, rule, mode):
				let declaration: Declaration
				= declarations[Int(rule)]

				try addBody(
					id,
					declaration.rule.syntax.ir,
					grammar: declaration.grammar,
					mode: mode,
				)

			case let .list(id, ir, grammar, mode):
				try addList(id, ir, grammar: grammar, mode: mode)

			case let .skip(id, grammar, silent):
				addSkip(id, grammar: grammar, silent: silent)
		}
	}

	/// 本体全体が選択肢なら、その枝を直接の生成規則にする。
	private mutating func addBody(
		_ id: Int32,
		_ body: [SyntaxIR],
		grammar: Int32,
		mode: Mode,
	) throws {
		if body.count == 1 {
			switch body[0] {
				case .choiceOf(let branches):
					for (index, branch) in branches.enumerated() {
						addProduction(
							id,
							try lower([branch], grammar: grammar, mode: mode),
							rank: Int32(branches.count - index - 1),
						)
					}

					return

				case .anyOf(let branches):
					for branch: Branch in branches {
						addProduction(
							id,
							try lower(
								branch.body,
								grammar: grammar,
								mode: mode,
							),
							rank: Int32(branch.precedence.rawValue),
						)
					}

					return

				default:
					break
			}
		}

		addProduction(id, try lower(body, grammar: grammar, mode: mode))
	}

	/// 先頭要素と「区切り＋要素」の反復、任意の末尾区切りへ分解する。
	/// 記号列は再利用できるので、要素の本体は一度だけ変換する。
	private mutating func addList(
		_ id: Int32,
		_ ir: SyntaxIR,
		grammar: Int32,
		mode: Mode,
	) throws {
		guard
			case let .list(body, separator, trailing, amount) = ir
		else { preconditionFailure() }

		if amount.min == 0 {
			addProduction(id, [])
		}

		if amount.max == 0 {
			return
		}

		let element: [Symbol]
		= try lower(body, grammar: grammar, mode: mode)

		let delimiter: [Symbol]
		= try lower(separator, grammar: grammar, mode: mode)

		let pair: Int32
		= nonterminal(
			.scoped(scope: identity(), label: -1),
			grammar: grammar,
		)

		addProduction(pair, delimiter + element)

		let rest: Int32
		= loop(
			body: pair,
			minimum: Swift.max(amount.min - 1, 0),
			maximum: amount.max.map { Swift.max($0 - 1, 0) },
			behavior: .eager,
			grammar: grammar,
		)

		let symbols: [Symbol]
		= element + [.nonterminal(rest, .none)]

		addProduction(id, symbols)

		if trailing == .allow {
			addProduction(id, symbols + delimiter)
		}
	}

	/// 字句Triviaの後で構文Triviaを試し、入力を消費したら字句Triviaへ戻る。
	private mutating func addSkip(
		_ id: Int32,
		grammar: Int32,
		silent: Bool,
	) {
		let plan: TriviaPlan
		= plans[Int(grammar)]

		let lexical: [Symbol]
		= plan.hasLexical ? [.trivia(triviaSite(grammar, silent: silent))] : []

		addProduction(id, lexical)

		for ir: SyntaxIR in plan.syntax {
			let wrapper: Int32
			= nonterminal(.transparent, grammar: grammar)

			tasks.append(
				.body(
					wrapper,
					[ir],
					grammar,
					.init(trivia: true, silent: silent),
				),
			)
			addProduction(
				id,
				[
					.nonterminal(id, .none),
					.nonterminal(wrapper, .nonEmpty),
				] + lexical,
			)
		}
	}

	private mutating func lower(
		_ body: [SyntaxIR],
		grammar: Int32,
		mode: Mode,
	) throws -> [Symbol] {
		var output: [Symbol] = []

		var pending: [Pending]
		= body.reversed().map { .syntax($0) }

		while let next: Pending = pending.popLast() {
			switch next {
				case let .loop(body, amount, behavior):
					output.append(
						repeated(
							body,
							amount,
							behavior,
							grammar: grammar,
							mode: mode,
						),
					)

				case .syntax(.enclosure(
					let body,
					let amount,
					let behavior,
					let opener,
					let closer,
				)):
					pending.append(
						contentsOf: closer.reversed().map { .syntax($0) },
					)

					if !body.isEmpty {
						pending.append(.loop(body, amount, behavior))
					}

					pending.append(
						contentsOf: opener.reversed().map { .syntax($0) },
					)

				case .syntax(let ir):
					try lower(
						ir,
						into: &output,
						grammar: grammar,
						mode: mode,
					)
			}
		}

		return output
	}

	private mutating func repeated(
		_ body: [SyntaxIR],
		_ amount: Amount,
		_ behavior: SyntaxRepetitionBehavior,
		grammar: Int32,
		mode: Mode,
	) -> Symbol {
		let iteration: Int32
		= nonterminal(
			.scoped(scope: identity(), label: -1),
			grammar: grammar,
		)

		tasks.append(.body(iteration, body, grammar, mode))

		return .nonterminal(
			loop(
				body: iteration,
				minimum: amount.min,
				maximum: amount.max,
				behavior: behavior,
				grammar: grammar,
			),
			.none,
		)
	}

	private mutating func lower(
		_ ir: SyntaxIR,
		into output: inout [Symbol],
		grammar: Int32,
		mode: Mode,
	) throws {
		switch ir {
			case let .token(label, pattern, spacious, tag):
				lexeme(
					pattern,
					label,
					spacious: spacious,
					tag: tag,
					words: nil,
					insensitive: false,
					into: &output,
					grammar: grammar,
					mode: mode,
				)

			case let .word(label, pattern, words, insensitive):
				lexeme(
					pattern,
					label,
					spacious: true,
					tag: nil,
					words: Array(Set(words)).sorted(),
					insensitive: insensitive,
					into: &output,
					grammar: grammar,
					mode: mode,
				)

			case let .tokenref(tag, spacious):
				if spacious && !mode.trivia {
					appendTriviaPrefix(to: &output, grammar: grammar)
				}

				references.append(
					.init(
						tag: self.tag(tag, grammar: grammar),
						atom: atom(.reference(grammar, tag, spacious)),
						grammar: grammar,
						silent: mode.silent,
					),
				)
				output.append(.reference(Int32(references.count - 1)))

			case let .ruleref(name, rule):
				let target: Int32
				= try resolve(name, rule, from: grammar)

				output.append(
					.nonterminal(ruleNonterminal(target, mode: mode), .none),
				)

			case .trivia:
				output.append(
					.nonterminal(
						explicitTriviaNonterminal(
							grammar,
							silent: mode.silent,
						),
						.none,
					),
				)

			case let .sequence(label, body):
				let id: Int32
				= nonterminal(
					.scoped(
						scope: identity(),
						label: self.label(label.ensure("#and")),
					),
					grammar: grammar,
				)

				tasks.append(.body(id, body, grammar, mode))
				output.append(.nonterminal(id, .none))

			case .choiceOf, .anyOf:
				let id: Int32
				= nonterminal(.transparent, grammar: grammar)

				tasks.append(.body(id, [ir], grammar, mode))
				output.append(.nonterminal(id, .none))

			case .optional(let body):
				let inner: Int32
				= nonterminal(
					.scoped(scope: identity(), label: -1),
					grammar: grammar,
				)

				tasks.append(.body(inner, body, grammar, mode))

				let id: Int32
				= nonterminal(
					.scoped(scope: identity(), label: -1),
					grammar: grammar,
				)

				addProduction(id, [.nonterminal(inner, .none)], rank: 1)
				addProduction(id, [], rank: 0)
				output.append(.nonterminal(id, .none))

			case let .repeat(body, amount, behavior):
				output.append(
					repeated(
						body,
						amount,
						behavior,
						grammar: grammar,
						mode: mode,
					),
				)

			case .list:
				let id: Int32
				= nonterminal(
					.scoped(scope: identity(), label: -1),
					grammar: grammar,
				)

				tasks.append(.list(id, ir, grammar, mode))
				output.append(.nonterminal(id, .none))

			case .enclosure:
				preconditionFailure("呼び出し元で連接へ展開する")

			case .capture(let body):
				let id: Int32
				= nonterminal(.capture, grammar: grammar)

				tasks.append(.body(id, body, grammar, mode))
				output.append(.nonterminal(id, .none))

			case .atomic(let body):
				output.append(
					.boundary(
						internalBoundary(
							body,
							probe: false,
							grammar: grammar,
							mode: mode,
						),
					),
				)

			case let .relabel(label, value):
				let id: Int32
				= nonterminal(
					.relabel(label: self.label(Label(label))),
					grammar: grammar,
				)

				tasks.append(.body(id, [value], grammar, mode))
				output.append(.nonterminal(id, .none))
		}
	}

	private mutating func lexeme(
		_ pattern: TokenIR,
		_ label: Label,
		spacious: Bool,
		tag: String?,
		words: [String]?,
		insensitive: Bool,
		into output: inout [Symbol],
		grammar: Int32,
		mode: Mode,
	) {
		var prefix: Int32 = -1

		if spacious && !mode.trivia {
			let plan: TriviaPlan
			= plans[Int(grammar)]

			if !plan.syntax.isEmpty {
				output.append(
					.nonterminal(skip(grammar, silent: true), .none),
				)
			}
			else if plan.hasLexical {
				// 字句Triviaだけなら、字句の照合に含めて項目を増やさない。
				prefix = plan.optional
			}
		}

		let key: PatternKey
		= .init(pattern)

		let atom: Int32
		= label == .none
			? atom(.lexical(key, spacious, words, insensitive))
			: identity()

		lexemes.append(
			.init(
				scanClass: scanClass(
					pattern,
					key: key,
					words: words,
					insensitive: insensitive,
					prefix: prefix,
				),
				label: self.label(label),
				tag: tag.map { self.tag($0, grammar: grammar) } ?? -1,
				atom: atom,
				grammar: grammar,
				silent: mode.silent,
			),
		)
		output.append(.lexeme(Int32(lexemes.count - 1)))
	}

	private mutating func scanClass(
		_ pattern: TokenIR,
		key: PatternKey,
		words: [String]?,
		insensitive: Bool,
		prefix: Int32,
	) -> Int32 {
		let classKey: ClassKey
		= .init(
			pattern: key,
			words: words,
			insensitive: insensitive,
			prefix: prefix,
		)

		if let id: Int32 = classIDs[classKey] {
			return id
		}

		let id: Int32
		= Int32(scanClasses.count)

		scanClasses.append(
			.init(
				program: program(pattern),
				prefix: prefix,
				hasWords: words != nil,
			),
		)
		scanDetails.append(
			.init(
				pattern: pattern,
				words: words,
				insensitive: insensitive,
			),
		)
		classIDs[classKey] = id

		return id
	}

}


// MARK: 実行用の索引

extension ModelBuilder {

	/// 空になり得ない本文の「空の回」は成立しないので、予測の対象から外す。
	private mutating func linkProductions() -> [Int32] {
		let nullable: [Bool]
		= nullableNonterminals()

		var order: [[Int32]]
		= .init(repeating: [], count: nonterminals.count)

		for index: Int in productions.indices {
			let production: GrammarModel.Production
			= productions[index]

			if case .final = production.action,
				case let .nonterminal(body, _)
					= symbols[Int(production.first) + 1],
				!nullable[Int(body)]
			{
				continue
			}

			order[Int(production.lhs)].append(Int32(index))
		}

		var flat: [Int32] = []

		for index: Int in nonterminals.indices {
			let start: Int32
			= Int32(flat.count)

			flat.append(contentsOf: order[index])
			nonterminals[index].productions = start..<Int32(flat.count)
		}

		return flat
	}

	private func nullableNonterminals() -> [Bool] {
		var nullable: [Bool]
		= .init(repeating: false, count: nonterminals.count)

		var changed: Bool = true

		while changed {
			changed = false

			for production: GrammarModel.Production in productions
			where !nullable[Int(production.lhs)] {
				if isNullable(production, nullable: nullable) {
					nullable[Int(production.lhs)] = true
					changed = true
				}
			}
		}

		return nullable
	}

	private func isNullable(
		_ production: GrammarModel.Production,
		nullable: [Bool],
	) -> Bool {
		var dot: Int
		= Int(production.first)

		while true {
			switch symbols[dot] {
				case .end:
					return true
				case .never:
					return false
				case .nonterminal(_, .nonEmpty), .nonterminal(_, .explicitTrivia):
					return false
				case let .nonterminal(id, _):
					if !nullable[Int(id)] {
						return false
					}
				case let .lexeme(id):
					let detail: GrammarModel.ScanDetail
					= scanDetails[Int(lexemes[Int(id)].scanClass)]

					if !detail.pattern.isNullable {
						return false
					}
				case .reference, .boundary, .trivia, .eos, .point:
					break
			}

			dot += 1
		}
	}

}
