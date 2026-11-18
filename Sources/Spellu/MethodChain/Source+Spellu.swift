import Basis


extension Source {

	/// 前方マッチ
	public func prefixMatch<Grammar : GrammarDeclaration>(
		from offset: Int? = nil,
		engine: Spellu.Engine? = nil,
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
			self,
			from: offset,
			method: .prefix,
			strategy: strategy,
			as: grammar[keyPath: rule],
		)
	}

	/// 前方マッチ
	public func prefixMatch(
		from offset: Int? = nil,
		engine: Spellu.Engine? = nil,
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
			self,
			from: offset,
			method: .prefix,
			strategy: strategy,
		)
	}

	/// 前方マッチ
	public func prefixMatch(
		from offset: Int? = nil,
		engine: Spellu.Engine? = nil,
		strategy: TreeStrategy = .compact,
		on grammars: any GrammarDeclaration...,
		label: Label = .none,
		spaces: [SpacePattern]? = nil,
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
			self,
			from: offset,
			method: .prefix,
			strategy: strategy,
		)
	}

	/// 全体マッチ
	public func wholeMatch<Grammar : GrammarDeclaration>(
		from offset: Int? = nil,
		engine: Spellu.Engine? = nil,
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
			self,
			from: offset,
			method: .whole,
			strategy: strategy,
			as: grammar[keyPath: rule],
		)
	}

	/// 全体マッチ
	public func wholeMatch(
		from offset: Int? = nil,
		engine: Spellu.Engine? = nil,
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
			self,
			from: offset,
			method: .whole,
			strategy: strategy,
		)
	}

	/// 全体マッチ
	public func wholeMatch(
		from offset: Int? = nil,
		engine: Spellu.Engine? = nil,
		strategy: TreeStrategy = .compact,
		on grammars: any GrammarDeclaration...,
		label: Label = .none,
		spaces: [SpacePattern]? = nil,
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
			self,
			from: offset,
			method: .whole,
			strategy: strategy,
		)
	}

}


