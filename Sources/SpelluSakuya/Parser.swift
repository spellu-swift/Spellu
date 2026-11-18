import Basis
import SpelluCore

/// 準備済みの不変モデルを複数の入力で再利用する。
package struct Parser: Sendable {

	let model: GrammarModel
	let limits: SafetyLimits

	package init(
		grammars: [SpelluGrammar],
		limits: SafetyLimits = .default,
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
		let start: Int = offset ?? source.range.lowerBound
		guard source.range.contains(start) || start == source.range.upperBound,
			start >= 0, start <= source.content.utf8.count
		else { throw SpelluError.invalidStartOffset(start) }
		let index: String.Index = source.content.utf8Index(start)
		guard index.samePosition(in: source.content.unicodeScalars) != nil
		else { throw SpelluError.invalidStartOffset(start) }
		let entry: RuleID = try model.start(rule)
		let session: Session = .init(
			model: model,
			source: source,
			limits: limits,
			start: start,
		)
		let match: Session.Match = try session.parse(
			entry,
			at: start,
			whole: method == .whole
		)
		let nodes: [SourceNode] = try session.store.materialize(
			match.trees,
			source: source,
			model: model,
			strategy: strategy,
		)
		guard nodes.count == 1, let node: SourceNode = nodes.first else {
			throw SpelluError.internalError(
				"Sakuya start rule must return one node"
			)
		}

		var trivia: [SourceNode] = []
		var cursor: [Int] = match.trivia == 0 ? [] : [match.trivia]
		while let span: TriviaSpan = try session.store.triviaLists.next(&cursor) {
			SourceTree.appendTrivia(
				grammar: model.grammars[span.grammar.index].name,
				source: source,
				range: span.range,
				continuing: span.continuing,
				to: &trivia,
			)
		}

		return SourceTree(
			root: node,
			trivia: trivia
		)
	}

}
