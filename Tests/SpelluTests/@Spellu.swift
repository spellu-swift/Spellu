import Spellu


@Suite struct SpelluTests {

	@Test(arguments: [Spellu.Engine.interpreter, .sakuya, .hoori])
	func 字句空白を読み飛ばしても自動Triviaには含めない(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: [.space]) {
			Token(label: "body", "a")
		}
		let source: Source = .temporary(" a ")
		let tree: SourceTree = try parser.parse(source)
		let root: SourceNode = try parser.parse(source)

		#expect(tree.root == root)
		#expect(tree.root.range == 1..<2)
		#expect(tree.trivia.isEmpty)
	}

	@Test func input_grammar() throws {
		let source: String
		= "#!/bin/bash"
	
		let tree: SourceNode
		= try Spellu()
			.input(BasisGrammar.default)
			.parse(source, as: BasisGrammar.$shebang)
		
		#expect(tree.string == source)
	}
	
	@Test func input_syntax_before() throws {
		let source: String
		= "@#!/bin/bash"
	
		#expect(throws: SpelluError.self) {
			try Spellu()
				.input {
					"@"
					BasisGrammar.$shebang
				}
				.input(BasisGrammar.default)
				.parse(source)
		}
	}
	
	@Test func input_syntax_after() throws {
		let source: String
		= "@#!/bin/bash"
	
		let tree: SourceNode
		= try Spellu()
			.input(BasisGrammar.default)
			.input {
				"@"
				BasisGrammar.$shebang
			}
			.parse(source)
		
		#expect(tree.string == source)
	}
	
}
