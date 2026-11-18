import Basis
import SpelluCore


package struct Parser : Sendable {

	let limits: Limits

	package init(
		grammars: [SpelluGrammar],
		limits: Limits = .default,
	) throws {
		self.limits = limits
	}

	package func parse(
		_ source: Source,
		from offset: Int? = nil,
		method: MatchMethod = .whole,
		treeStrategy: TreeStrategy,
		as rule: RuleReference? = nil,
	) throws -> SourceNode {
		GeneralError.Fatal.noImplementation()
	}

}
