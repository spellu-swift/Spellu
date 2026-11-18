import Basis


extension File {

	/// ファイル全体マッチ
	public func wholeMatch<Grammar : GrammarDeclaration>(
		from offset: Int = 0,
		engine: Spellu.Engine? = nil,
		tabIndentation: Int? = nil,
		strategy: TreeStrategy = .compact,
		on grammar: Grammar,
		_ grammars: any GrammarDeclaration...,
		as rule: KeyPath<Grammar, RuleReference>,
	) throws -> SourceNode {
		try Spellu(
			engine: engine,
		)
		.input([grammar] + grammars)
		.parse(
			.file(path: path, tabIndentation: tabIndentation),
			from: offset,
			method: .whole,
			strategy: strategy,
			as: grammar[keyPath: rule],
		)
	}

	/// ファイル全体マッチ
	public func wholeMatch(
		from offset: Int = 0,
		engine: Spellu.Engine? = nil,
		tabIndentation: Int? = nil,
		strategy: TreeStrategy = .compact,
		on grammars: any GrammarDeclaration...,
		spaces: [SpacePattern]? = nil,
		label: Label = .none,
		as syntax: Syntax,
	) throws -> SourceNode {
		try Spellu(
			engine: engine,
		)
		.input(grammars)
		.input(
			spaces: spaces,
			label: label,
			syntax: syntax,
		)
		.parse(
			.file(path: path, tabIndentation: tabIndentation),
			from: offset,
			method: .whole,
			strategy: strategy,
		)
	}

	/// ファイル全体マッチ
	public func wholeMatch(
		from offset: Int = 0,
		engine: Spellu.Engine? = nil,
		tabIndentation: Int? = nil,
		strategy: TreeStrategy = .compact,
		on grammars: any GrammarDeclaration...,
		spaces: [SpacePattern]? = nil,
		label: Label = .none,
		@SyntaxBuilder as syntax: () -> [SyntaxIR],
	) throws -> SourceNode {
		try Spellu(
			engine: engine,
		)
		.input(grammars)
		.input(
			spaces: spaces,
			label: label,
			syntax: syntax,
		)
		.parse(
			.file(path: path, tabIndentation: tabIndentation),
			from: offset,
			method: .whole,
			strategy: strategy,
		)
	}

}


