import Basis
import SpelluCore


///
/// Interpreter v5
///
/// SyntaxIRを実行時に読み、古典的なGLL法で構文解析する。
/// 準備するのは命令列の表だけで、同じParserを複数の入力で使い回せる。
///
package struct Parser : Sendable {

	let table: CodeTable
	let limits: Limits

	package init(
		grammars: [SpelluGrammar],
		limits: Limits = .default,
	) throws {
		var builder: CodeTableBuilder = .init()

		self.table = try builder.build(grammars)
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

		let entry: RuleID
		= try table.start(rule)

		var session: Session
		= .init(
			table: table,
			source: source,
			limits: limits,
			start: start,
		)

		let match: Match
		= try session.parse(
			method == .whole ? .whole(entry) : .rule(entry),
			at: start,
		)

		let nodes: [SourceNode]
		= try TreeBuilder().build(
			match.trees,
			strategy: strategy,
			&session,
		)

		guard
			nodes.count == 1,
			let node: SourceNode = nodes.first
		else {
			throw SpelluError.internalError(
				"Interpreter start rule must return one node",
			)
		}

		var trivia: [SourceNode] = []

		for span in session.store.triviaLists.elements(match.trivia) {
			SourceTree.appendTrivia(
				grammar: table[span.grammar].name,
				source: source,
				range: span.begin..<span.end,
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
