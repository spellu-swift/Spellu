import Basis
import SpelluCore


/// 準備済みの不変モデルを複数の入力で再利用する。
package struct Parser : Sendable {

	let model: GrammarModel
	let limits: HooriLimits

	package init(
		grammars: [SpelluGrammar],
		limits: HooriLimits = .default,
	) throws {
		var builder: ModelBuilder = .init()

		self.model = try builder.build(grammars)
		self.limits = limits
	}

	package func parse(
		_ source: Source,
		from offset: Int? = nil,
		method: MatchMethod = .whole,
		strategy: TreeStrategy,
		as rule: RuleReference? = nil,
	) throws -> SourceTree {
		let start: Int
		= offset ?? source.range.lowerBound

		guard
			source.range.contains(start) || start == source.range.upperBound,
			start >= 0,
			start <= source.content.utf8.count
		else { throw SpelluError.invalidStartOffset(start) }

		let index: String.Index
		= source.content.utf8Index(start)

		guard
			index.samePosition(in: source.content.unicodeScalars) != nil
		else { throw SpelluError.invalidStartOffset(start) }

		// 項目は位置をInt32で持つ。
		guard
			source.range.upperBound <= Int(Int32.max)
		else {
			throw SpelluError.safetyStop(
				.other("Hoori source is too long"),
			)
		}

		let entry: GrammarModel.Rule
		= model.rules[Int(try model.start(rule))]

		var session: Session
		= .init(
			model: model,
			source: source,
			limits: limits,
			start: Int32(start),
		)

		let match: Match
		= try session.parse(
			entry: method == .whole ? entry.whole : entry.nonterminal,
			at: Int32(start),
		)

		let nodes: [SourceNode]
		= try session.materialize(match.trees, strategy: strategy)

		guard
			nodes.count == 1,
			let node: SourceNode = nodes.first
		else {
			throw SpelluError.internalError(
				"Hoori start rule must return one node",
			)
		}

		var trivia: [SourceNode] = []

		for span in session.store.spans(match.trivia) {
			SourceTree.appendTrivia(
				grammar: model.grammars[Int(span.grammar)].name,
				source: source,
				range: Int(span.begin)..<Int(span.end),
				continuing: span.continuing,
				to: &trivia,
			)
		}

		return SourceTree(
			root: node,
			trivia: trivia,
		)
	}

}
