@_exported import UnitTesting
import Spellu


///
/// 互換性テスト
///  - TreeStrategy{.asis, .compact}の出力をテストする。
///  - 指定されたSpellu.Engineをテストする。
///
func compatibleTest(
	_ engines: [Spellu.Engine],
	rule: Syntax,
	spaces: [SpacePattern]? = nil,
	source: String,
	match: String,
	asis: TreeTuple<Label, String>,
	compact: TreeTuple<Label, String>,
	dump: Bool = false,
	file: String = #fileID,
	line: Int = #line,
) throws {
	let benchmarkGrammar: SpelluGrammar = .init(
		name: "_", spaces: spaces ?? [.space],
		rules: [(name: "$", label: .none, expose: true, syntax: rule)]
	)
	benchmarkCompatible(engines, grammars: [benchmarkGrammar], source: source, file: file, line: line) { engine in
		let parser: Spellu = try Spellu(engine: engine).input(benchmarkGrammar)
		return { try parser.parse($0, method: .whole, strategy: .asis) }
	}

	for engine in engines {
		let tree: SourceNode
		= try source.wholeMatch(
			engine: engine,
			strategy: .asis,
			spaces: spaces,
			as: { return rule.ir },
		)
		
		if dump {
			#print("\(engine.compatibleName): AS-IS")
			tree.dumpTree()
		}
		
		#expect(tree.string == match, "\(engine.compatibleName): ASIS: \(tree.renderTree().asText)")
		#expect(tree.asTreeTuple == asis, "\(engine.compatibleName): ASIS: \(tree.renderTree().asText)")
	}
	
	for engine in engines {
		let tree: SourceNode
		= try source.wholeMatch(
			engine: engine,
			strategy: .compact,
			spaces: spaces,
			as: { return rule.ir },
		)
		
		if dump {
			#print("COMPACT")
			tree.dumpTree()
		}
		
		#expect(tree.string == match, "\(engine.compatibleName): COMPACT: \(tree.renderTree().asText)")
		#expect(tree.asTreeTuple == compact, "\(engine.compatibleName): COMPACT: \(tree.renderTree().asText)")
	}
}
	
func compatibleTest(
	_ engines: [Spellu.Engine],
	rule: Syntax,
	spaces: [SpacePattern]? = nil,
	source: String,
	error: SpelluError,
	file: String = #fileID,
	line: Int = #line,
) throws {
	let benchmarkGrammar: SpelluGrammar = .init(
		name: "_", spaces: spaces ?? [.space],
		rules: [(name: "$", label: .none, expose: true, syntax: rule)]
	)
	benchmarkCompatible(engines, grammars: [benchmarkGrammar], source: source, file: file, line: line) { engine in
		let parser: Spellu = try Spellu(engine: engine).input(benchmarkGrammar)
		return { try parser.parse($0, method: .whole, strategy: .asis) }
	}

	for engine in engines {
		for strategy: TreeStrategy in [.asis, .compact] {
			#expect(throws: error, "\(engine.compatibleName): \(strategy)") {
				try source.wholeMatch(
					engine: engine,
					strategy: strategy,
					spaces: spaces,
					as: { return rule.ir },
				)
			}
		}
	}
}

/// 登録文法と開始ルールを指定して、両方の木の出力を比較する。
func compatibleTest(
	_ engines: [Spellu.Engine],
	grammars: [SpelluGrammar],
	startRule: RuleReference,
	source: String,
	match: String,
	asis: TreeTuple<Label, String>,
	compact: TreeTuple<Label, String>,
	file: String = #fileID,
	line: Int = #line,
) throws {
	benchmarkCompatible(engines, grammars: grammars, source: source, file: file, line: line) { engine in
		let parser: Spellu = try Spellu(engine: engine).input(grammars)
		return { try parser.parse($0, strategy: .asis, as: startRule) }
	}

	for engine in engines {
		let parser: Spellu = try Spellu(engine: engine).input(grammars)
		for strategy: TreeStrategy in [.asis, .compact] {
			let tree: SourceNode = try parser.parse(
				source, strategy: strategy, as: startRule,
			)
			let expected: TreeTuple<Label, String>
			= strategy == .asis ? asis : compact

			#expect(tree.string == match, "\(engine.compatibleName): \(strategy)")
			#expect(tree.asTreeTuple == expected,
				"\(engine.compatibleName): \(strategy): \(tree.renderTree().asText)")
		}
	}
}

func compatibleTest(
	_ engines: [Spellu.Engine],
	grammars: [SpelluGrammar],
	startRule: RuleReference,
	source: String,
	error: SpelluError,
	file: String = #fileID,
	line: Int = #line,
) throws {
	benchmarkCompatible(engines, grammars: grammars, source: source, file: file, line: line) { engine in
		let parser: Spellu = try Spellu(engine: engine).input(grammars)
		return { try parser.parse($0, strategy: .asis, as: startRule) }
	}

	for engine in engines {
		let parser: Spellu = try Spellu(engine: engine).input(grammars)
		for strategy: TreeStrategy in [.asis, .compact] {
			#expect(throws: error, "\(engine.compatibleName): \(strategy)") {
				try parser.parse(source, strategy: strategy, as: startRule)
			}
		}
	}
}


private extension Spellu.Engine {

	var compatibleName: String {
		description
	}

}

/// 自動Triviaの互換性テスト
///  - 自動Triviaを集めるエンジンで、`SourceTree.trivia` の範囲を比べる。
///  - TreeStrategy{.asis, .compact}のどちらでも同じ範囲になることを確かめる。
///  - 各要素は文法 `_` の `#trivia` の葉になる。
func compatibleTriviaTest(
	_ engines: [Spellu.Engine],
	rule: Syntax,
	spaces: [SpacePattern]? = nil,
	source: String,
	method: MatchMethod = .whole,
	trivia: [Range<Int>],
	file: String = #fileID,
	line: Int = #line,
) throws {
	let grammar: SpelluGrammar = .init(
		name: "_", spaces: spaces ?? [.space],
		rules: [(name: "$", label: .none, expose: true, syntax: rule)]
	)

	try compatibleTriviaTest(
		engines,
		grammar: grammar,
		source: source,
		method: method,
		trivia: trivia,
		file: file,
		line: line,
	)
}

/// 構文Triviaの規則を持つ文法で、自動Triviaの互換性を確かめる。
func compatibleTriviaTest(
	_ engines: [Spellu.Engine],
	grammar: SpelluGrammar,
	source: String,
	method: MatchMethod = .whole,
	trivia: [Range<Int>],
	file: String = #fileID,
	line: Int = #line,
) throws {
	for engine in engines {
		let parser: Spellu = try Spellu(engine: engine).input(grammar)
		for strategy: TreeStrategy in [.asis, .compact] {
			let tree: SourceTree = try parser.parse(
				.temporary(source), method: method, strategy: strategy,
			)
			#expect(tree.trivia.map(\.range) == trivia,
				"\(engine.compatibleName): \(strategy)")
			#expect(tree.trivia.allSatisfy { $0.grammar == "_" && $0.label == "#trivia" },
				"\(engine.compatibleName): \(strategy)")
		}
	}
}
