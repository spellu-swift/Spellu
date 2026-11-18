


extension [Source] {

	/// 同じ文法とエンジンで各ソースを全体マッチする。
	public func wholeMatch<Grammar : GrammarDeclaration>(
		engine: Spellu.Engine? = nil,
		strategy: TreeStrategy = .compact,
		on grammar: Grammar,
		_ grammars: any GrammarDeclaration...,
		as rule: KeyPath<Grammar, RuleReference>,
	) throws -> [SourceNode] {
		let spellu: Spellu
		= try Spellu(
			engine: engine,
			on: [grammar] + grammars,
		)

		let reference: RuleReference
		= grammar[keyPath: rule]

		return try map { source in
			try spellu.parse(
				source,
				method: .whole,
				strategy: strategy,
				as: reference,
			)
		}
	}

}
