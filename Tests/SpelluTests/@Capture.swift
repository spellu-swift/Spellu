import Spellu


@Suite struct CaptureTests {

	static let engines: [Spellu.Engine] = [.interpreter, .sakuya, .hoori]

	@Test(arguments: engines)
	func 再帰で内側の記録を閉じた後に外側の記録を参照する(
		engine: Spellu.Engine,
	) throws {
		let grammar: SpelluGrammar = .init(name: "Nested", spaces: [], trivia: [], rules: [
			("root", "root", true, Syntax {
				Capture {
					Fragment("[")
					Fragment(tag: "mark") { "#".repeat(1...) }
					Fragment(":")
					ChoiceOf {
						SyntaxIR.ruleref(nil, "root")
						Fragment("x")
					}
					Fragment(":")
					Fragment(tag: "mark")
					Fragment("]")
				}
			}),
		])
		let parser: Spellu = try Spellu(engine: engine).input(grammar)

		#expect(try parser.parse("[#:[##:x:##]:#]").string == "[#:[##:x:##]:#]")
		expectUnexpectedMatch { try parser.parse("[#:[##:x:##]:##]") }
	}

	@Test(arguments: engines)
	func Captureの内側から外側を参照でき記録と構文木を分離する(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Fragment(tag: "mark", "a")
			Capture {
				Fragment(tag: "mark").as(label: "inherited")
				Fragment(tag: "mark", "b")
				Fragment(tag: "local", "c")
				Fragment(tag: "mark").as(label: "shadowed")
			}
			Fragment(tag: "mark").as(label: "restored")
			Optional { Fragment(tag: "local") }
		}
		let result: SourceNode = try parser.parse("aabcba", strategy: .compact)

		#expect(result.parts.map(\.label) == ["inherited", "shadowed", "restored"])
		#expect(result.parts.map(\.string) == ["a", "b", "a"])
		expectUnexpectedMatch { try parser.parse("aabcbac") }
	}

	@Test(arguments: engines)
	func 失敗したCaptureで記録を残さない(engine: Spellu.Engine) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Fragment(tag: "mark", "a")
			Optional {
				Capture {
					Fragment(tag: "mark", "b")
					Fragment("!")
				}
			}
			Fragment("b")
			Fragment(tag: "mark")
		}

		#expect(try parser.parse("aba").string == "aba")
		expectUnexpectedMatch { try parser.parse("abb") }
	}

	@Test(arguments: [Spellu.Engine.interpreter, .sakuya, .hoori])
	func Capture内の候補を外側の構文まで保持する(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Capture {
				ChoiceOf {
					Fragment("a")
					Sequence { Fragment("a"); Fragment("b") }
				}
			}
			Fragment("c")
		}

		#expect(try parser.parse("abc").string == "abc")
	}

}


extension CaptureTests {
	@Test(arguments: engines, [
		("#\"a\\#(##\"b\"##)c\"#", ["\\#(##\"b\"##)"]),
		("#\"a\\#(##\"b\"##)c\\#(1)d\"#", ["\\#(##\"b\"##)", "\\#(1)"]),
	])
	func Swift風の文字列で入れ子の補間を木に残す(
		engine: Spellu.Engine,
		example: (String, [String]),
	) throws {
		let (input, interpolations) = example
		let grammar: SpelluGrammar = .init(name: "RawString", spaces: [], trivia: [], rules: [
			("str0", "str0", true, rawString {
				ChoiceOf {
					Sequence(label: "interp") {
						Fragment("\\")
						Fragment(tag: "pounds")
						Fragment("(")
						ChoiceOf {
							SyntaxIR.ruleref(nil, "str1")
							Fragment("1")
						}
						Fragment(")")
					}
					Fragment { CharacterClass.range("a"..."z") }
				}
			}),
			("str1", "str1", false, rawString {
				Fragment { CharacterClass.range("a"..."z") }
			}),
		])
		let parser: Spellu = try Spellu(engine: engine).input(grammar)
		let result: SourceNode = try parser.parse(input, strategy: .compact)

		#expect(result.label == "str0")
		#expect(result.string == input)
		let labels: [Label] = .init(repeating: "interp", count: interpolations.count)
		#expect(result.parts.map(\.label) == labels)
		#expect(result.parts.map(\.string) == interpolations)
		let nested: SourceNode = try #require(result.parts.first?.parts.first)
		#expect(nested.label == "str1")
		#expect(nested.string == "##\"b\"##")
	}

	private func rawString(
		@SyntaxBuilder _ body: () -> [SyntaxIR],
	) -> Syntax {
		Syntax {
			Capture {
				Enclosure(0..., behavior: .reluctant) {
					body()
				} opener: {
					Fragment(tag: "pounds") { "#".repeat(1...) }
					Fragment("\"")
				} closer: {
					Fragment("\"")
					Fragment(tag: "pounds")
				}
			}
		}
	}
}
