import Basis
import SpelluCore
import SpelluLex


///
/// 命令列の表を作る
///
/// 文法を検査し、ルールの本文と、その中の複合の命令が持つ子の命令列に番号を振る。
/// 構文の入れ子はSwiftの呼び出しに変えず、未処理の命令列の配列で順にたどる。
///
struct CodeTableBuilder {

	private struct Declaration {
		let grammar: GrammarID
		let rule: SpelluRule
	}

	private var sources: [SpelluGrammar] = []
	private var grammarIDs: [String: GrammarID] = [:]
	private var ruleNames: [[String: RuleID]] = []
	private var declarations: [Declaration] = []
	private var blocks: [CodeTable.Block] = []
	private var children: [Location: [BlockID]] = [:]
	private var references: [Location: RuleID] = [:]
	private var segments: [BlockID: [CodeTable.Segment]] = [:]
	private var tokens: [Location: TokenID] = [:]

	mutating func build(
		_ grammars: [SpelluGrammar],
	) throws -> CodeTable {
		for grammar: SpelluGrammar in grammars {
			guard
				grammarIDs[grammar.name] == nil
			else { throw SpelluError.duplicateGrammar(grammar: grammar.name) }

			_ = try register(grammar)
		}

		try collectEmbeddedRules()

		var rules: [CodeTable.Rule] = []
		var pending: [BlockID] = []

		for declaration: Declaration in declarations {
			let body: BlockID
			= addBlock(declaration.rule.syntax.ir, grammar: declaration.grammar)

			rules.append(
				.init(
					grammar: declaration.grammar,
					name: declaration.rule.name,
					label: declaration.rule.label.ensure(declaration.rule.name),
					body: body,
				),
			)
			pending.append(body)
		}

		// 構文Triviaも命令列として番号を振る。
		var syntaxTrivia: [[BlockID]] = []

		for (index, source) in sources.enumerated() {
			var blocks: [BlockID] = []

			for ir: SyntaxIR in syntaxTriviaCode(of: source) {
				let block: BlockID
				= addBlock([ir], grammar: .init(rawValue: index))

				blocks.append(block)
				pending.append(block)
			}

			syntaxTrivia.append(blocks)
		}

		while let block: BlockID = pending.popLast() {
			pending.append(contentsOf: try number(block))
		}

		var grammarTable: [CodeTable.Grammar] = []

		for (index, source) in sources.enumerated() {
			grammarTable.append(
				.init(
					name: source.name,
					rules: ruleNames[index],
					entry: source.rules.first(where: \.expose).flatMap {
						ruleNames[index][$0.name]
					},
					lexicalTrivia: lexicalTrivia(of: source),
					syntaxTrivia: syntaxTrivia[index],
				),
			)
		}

		return .init(
			blocks: blocks,
			grammars: grammarTable,
			rules: rules,
			children: children,
			references: references,
			segments: segments,
			tokens: tokens,
		)
	}

}


// MARK: 文法とルールの登録

extension CodeTableBuilder {

	private mutating func register(
		_ grammar: SpelluGrammar,
	) throws -> GrammarID {
		if let id: GrammarID = grammarIDs[grammar.name] {
			return id
		}

		try validate(grammar)

		let id: GrammarID
		= .init(rawValue: sources.count)

		grammarIDs[grammar.name] = id
		sources.append(grammar)
		ruleNames.append([:])

		for rule: SpelluRule in grammar.rules {
			guard
				ruleNames[id.rawValue][rule.name] == nil
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
		in grammar: GrammarID,
	) {
		ruleNames[grammar.rawValue][rule.name]
		= .init(rawValue: declarations.count)

		declarations.append(.init(grammar: grammar, rule: rule))
	}

	/// 命令に埋め込まれた `_rule` も先に登録し、ルールの番号を確定する。
	private mutating func collectEmbeddedRules() throws {
		var scanned: Int = 0

		while scanned < sources.count {
			var pending: [SyntaxIR]
			= sources[scanned].rules.flatMap(\.syntax.ir)
				+ syntaxTriviaCode(of: sources[scanned])

			while let instruction: SyntaxIR = pending.popLast() {
				for body: [SyntaxIR] in childCode(of: instruction) {
					pending.append(contentsOf: body)
				}
			}

			scanned += 1
		}
	}

	/// ルール参照を解決する。別の文法の非公開ルールは参照できない。
	private func resolve(
		_ name: String?,
		_ rule: String,
		from owner: GrammarID,
	) throws -> RuleID {
		let grammarName: String
		= name ?? sources[owner.rawValue].name

		guard
			let target: GrammarID = grammarIDs[grammarName]
		else { throw SpelluError.grammarNotFound(grammar: grammarName) }

		guard
			let id: RuleID = ruleNames[target.rawValue][rule]
		else {
			throw SpelluError.ruleNotFound(
				grammar: grammarName,
				rule: rule,
			)
		}

		if target != owner && !declarations[id.rawValue].rule.expose {
			throw SpelluError.ruleNotFound(
				grammar: grammarName,
				rule: rule,
			)
		}

		return id
	}

	/// 文法のTriviaのうち、字句のパターン。
	private func lexicalTrivia(
		of grammar: SpelluGrammar,
	) -> [TokenIR] {
		grammar.spaces.map { space in
			switch space {
				case .space:
					.character(.include(.space))
				case .newline:
					.character(.include(.newline))
				case .character(let value):
					.character(value.set)
				case .string(let value):
					.string(value)
				case .token(let value):
					value
			}
		}
	}

	/// 文法のTriviaのうち、構文で書いたもの。
	private func syntaxTriviaCode(
		of grammar: SpelluGrammar,
	) -> [SyntaxIR] {
		grammar.trivia.map { rule in
			.ruleref(nil, rule)
		}
	}

}


// MARK: 命令列の番号

extension CodeTableBuilder {

	private mutating func addBlock(
		_ code: [SyntaxIR],
		grammar: GrammarID,
	) -> BlockID {
		let id: BlockID
		= .init(rawValue: blocks.count)

		blocks.append(.init(grammar: grammar, code: code))

		return id
	}

	/// 命令列の命令を調べ、子の命令列と字句に番号を振り、ルール参照を解決する。
	/// 新しく番号を振った子の命令列を返す。
	private mutating func number(
		_ block: BlockID,
	) throws -> [BlockID] {
		let grammar: GrammarID
		= blocks[block.rawValue].grammar

		var added: [BlockID] = []

		for (pc, instruction) in blocks[block.rawValue].code.enumerated() {
			let location: Location
			= .init(block: block, pc: pc)

			// 複製した命令は、元の命令が子の命令列と参照先を持つ。
			if CodeTable.canonical(location, in: segments) != location {
				continue
			}

			switch instruction {
				case let .ruleref(name, target):
					references[location] = try resolve(
						name,
						target,
						from: grammar,
					)

				case .token, .word:
					tokens[location] = .init(rawValue: tokens.count)

				case let .list(value, separator, trailing, amount):
					added += listAlternatives(
						at: location,
						value,
						separator: separator,
						trailing: trailing,
						amount: amount,
						grammar: grammar,
					)

				default:
					// Listの残りの本文のように、先に登録した子の命令列はそのまま使う。
					guard
						children[location] == nil
					else { break }

					let ids: [BlockID]
					= childCode(of: instruction).map {
						addBlock($0, grammar: grammar)
					}

					if !ids.isEmpty {
						children[location] = ids
						added += ids
					}
			}
		}

		return added
	}

	/// 複合の命令の子の命令列。
	private func childCode(
		of instruction: SyntaxIR,
	) -> [[SyntaxIR]] {
		switch instruction {
			case let .sequence(_, body),
				let .optional(body),
				let .atomic(body),
				let .capture(body),
				let .repeat(body, _, _):
				[body]

			case let .choiceOf(branches):
				branches.map { [$0] }

			case let .anyOf(branches):
				branches.map(\.body)

			case let .relabel(_, value):
				[[value]]

			case let .list(value, separator, _, _):
				// Listの選択肢は `listAlternatives` で作る。ここでは埋め込みの
				// ルールを集めるために、要素と区切りを返す。
				[value, separator]

			case let .enclosure(body, amount, behavior, opener, closer):
				[
					opener
						+ (body.isEmpty ? [] : [
							.repeat(body, amount, behavior: behavior),
						])
						+ closer,
				]

			default:
				[]
		}
	}

	/// Listの選択肢の補助の命令列を作り、子の命令列として登録する。
	///
	/// 最小回数が0なら空の選択肢、上限が0でなければ「要素＋残り」と、
	/// 末尾の区切りを許すなら「要素＋残り＋区切り」。残りは「区切り＋要素」の反復で、
	/// 回数は要素一つ分を差し引く。
	///
	/// 要素と残りは選択肢ごとに複製し、残りの本文の要素も複製する。複製した命令は
	/// 元の命令に対応させ（`segments`）、呼び出しとAtomを共有する。Hooriが要素の
	/// 記号列を一度だけ変換して、選択肢と残りで使い回すのと同じ。
	/// 新しく番号を振った命令列を返す。
	private mutating func listAlternatives(
		at location: Location,
		_ value: [SyntaxIR],
		separator: [SyntaxIR],
		trailing: Acceptance,
		amount: Amount,
		grammar: GrammarID,
	) -> [BlockID] {
		var alternatives: [BlockID] = []
		var added: [BlockID] = []

		if amount.min == 0 {
			alternatives.append(addBlock([], grammar: grammar))
		}

		if amount.max != 0 {
			let minimum: Int
			= Swift.max(amount.min - 1, 0)

			let rest: SyntaxIR
			= .repeat(
				separator + value,
				amount.max.map { .range(minimum, Swift.max($0 - 1, 0)) }
					?? .nOrMore(minimum),
				behavior: .eager,
			)

			// 元になる「要素＋残り」と、残りの本文「区切り＋要素」。
			let head: BlockID
			= addBlock(value + [rest], grammar: grammar)

			let pair: BlockID
			= addBlock(separator + value, grammar: grammar)

			children[.init(block: head, pc: value.count)] = [pair]
			segments[pair] = [
				.init(
					range: separator.count..<separator.count + value.count,
					origin: head,
					start: 0,
				),
			]

			alternatives.append(head)
			added.append(pair)

			if trailing == .allow {
				let tail: BlockID
				= addBlock(value + [rest] + separator, grammar: grammar)

				// 末尾の区切りは、残りの本文の区切りの複製。
				let headCount: Int
				= value.count + 1

				segments[tail] = [
					.init(range: 0..<headCount, origin: head, start: 0),
					.init(
						range: headCount..<headCount + separator.count,
						origin: pair,
						start: 0,
					),
				]

				alternatives.append(tail)
			}
		}

		children[location] = alternatives

		return alternatives + added
	}

}
