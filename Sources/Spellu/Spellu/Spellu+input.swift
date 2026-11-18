extension Spellu {
	
	/// 文法を追加した新しいインスタンスを返す。失敗時も元の登録を保持する。
	public func input(
		_ grammar: any GrammarDeclaration,
		_ others: any GrammarDeclaration...,
	) throws -> Self {
		try input([grammar] + others)
	}
	
	public func input(
		_ grammars: [any GrammarDeclaration],
	) throws -> Self {
		try input(grammars.map { $0.grammar() })
	}
	
	public func input(
		_ grammar: SpelluGrammar,
		_ others: SpelluGrammar...,
	) throws -> Self {
		try input([grammar] + others)
	}

	public func input(
		_ grammars: [SpelluGrammar],
	) throws -> Self {
		let combined: [SpelluGrammar]
		= grammars + self.grammars
		
		try Self.check(combined)
		
		return try Spellu(
			engine: engine,
			grammars: combined,
			backend: Spellu.prepare(
				combined,
				for: engine,
			)
		)
	}
	
	@discardableResult
	public func input(
		spaces: [SpacePattern]? = nil,
		label: Label = .none,
		syntax: Syntax,
	) throws -> Self {
		try input(
			[
				SpelluGrammar(
					name: "_",
					spaces: spaces ?? [.space],
					trivia: [],
					rules: [(
						name: "$",
						label: label,
						expose: true,
						syntax: syntax,
					)],
				),
			]
		)
	}
	
	@discardableResult
	public func input(
		spaces: [SpacePattern]? = nil,
		label: Label = .none,
		@SyntaxBuilder syntax: () -> [SyntaxIR],
	) throws -> Self {
		try input(
			spaces: spaces,
			label: label,
			syntax: Syntax(syntax),
		)
	}
	
}




