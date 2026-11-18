extension [File] {

	/// 同じ文法とエンジンで各ファイルを全体マッチする。
	public func wholeMatch<Grammar : GrammarDeclaration>(
		tabIndentation: Int? = nil,
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

		return try parse(
			tabIndentation: tabIndentation,
			strategy: strategy,
			with: spellu,
			as: grammar[keyPath: rule],
		)
	}

	public func wholeMatch(
		tabIndentation: Int? = nil,
		engine: Spellu.Engine? = nil,
		strategy: TreeStrategy = .compact,
		on grammars: any GrammarDeclaration...,
		spaces: [SpacePattern]? = nil,
		label: Label = .none,
		as syntax: Syntax,
	) throws -> [SourceNode] {
		let spellu: Spellu
		= try Spellu(
			engine: engine,
			on: grammars,
		)
		.input(grammars)
		.input(spaces: spaces, label: label, syntax: syntax)

		return try parse(
			tabIndentation: tabIndentation,
			strategy: strategy,
			with: spellu,
		)
	}

	public func wholeMatch(
		tabIndentation: Int? = nil,
		engine: Spellu.Engine? = nil,
		strategy: TreeStrategy = .compact,
		on grammars: any GrammarDeclaration...,
		spaces: [SpacePattern]? = nil,
		label: Label = .none,
		@SyntaxBuilder as syntax: () -> [SyntaxIR],
	) throws -> [SourceNode] {
		let spellu: Spellu
		= try Spellu(engine: engine)
			.input(grammars)
			.input(spaces: spaces, label: label, syntax: syntax)

		return try parse(
			tabIndentation: tabIndentation,
			strategy: strategy,
			with: spellu,
		)
	}

	private func parse(
		tabIndentation: Int?,
		strategy: TreeStrategy,
		with spellu: Spellu,
		as rule: RuleReference? = nil,
	) throws -> [SourceNode] {
		try map { file in
			try spellu.parse(
				.file(path: file.path, tabIndentation: tabIndentation),
				method: .whole,
				strategy: strategy,
				as: rule,
			)
		}
	}

}
