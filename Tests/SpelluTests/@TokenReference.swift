import Spellu

// 記録・参照と経路の巻き戻しを、対応する各エンジンで確認する。
@Suite struct TokenReferenceTests {
	static let engines: [Spellu.Engine] = [.interpreter, .sakuya, .hoori]

	@Test(arguments: engines)
	func 共通接頭辞があってもtagには元の字句全体を記録する(
		engine: Spellu.Engine,
	) throws {
		let grammar: SpelluGrammar = .init(name: "G", spaces: [], trivia: [], rules: [
			("root", "root", true, Syntax {
				Optional { Fragment(tag: "x", "abc") }
				Fragment(":")
				Fragment(tag: "x")
			}),
			("other", "other", false, Syntax { Fragment("ab") }),
		])
		let parser: Spellu = try Spellu(engine: engine).input(grammar)
		#expect(try parser.parse("abc:ABC").string == "abc:ABC")
		#expect(throws: SpelluError.self) { try parser.parse(":ABC") }
	}

	@Test(arguments: engines)
	func Luaの長いコメントで閉じ記号の等号数を一致させる(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Enclosure(0..., behavior: .reluctant) {
				Fragment { Character.all }
			} opener: {
				Fragment("--[")
				Fragment(tag: "delimiter") { "=".repeat(0...) }
				Fragment("[")
			} closer: {
				Fragment("]")
				Fragment(tag: "delimiter")
				Fragment("]")
			}
		}
		#expect(try parser.parse("--[=[a]]b]=]").string == "--[=[a]]b]=]")
		#expect(try parser.parse("--[[a]]").string == "--[[a]]")
		#expect(throws: SpelluError.self) { try parser.parse("--[=[a]]") }
	}

	@Test(arguments: engines)
	func 構文Triviaで成功した記録を後続から参照する(
		engine: Spellu.Engine,
	) throws {
		let grammar: SpelluGrammar = .init(name: "G", spaces: [], trivia: [
			"comment",
		], rules: [
			("root", "root", true, Syntax {
				Token(":")
				Fragment(tag: "x")
			}),
			("comment", "comment", false, Syntax {
				Fragment("[")
				Fragment(tag: "x", "a")
				Fragment("]")
			}),
		])
		let parser: Spellu = try Spellu(engine: engine).input(grammar)
		#expect(try parser.parse("[a]:A").string == ":A")
	}

	@Test(arguments: engines)
	func 別文法の同名tagは互いを上書きせず未記録を共有しない(
		engine: Spellu.Engine,
	) throws {
		let outer: SpelluGrammar = .init(name: "Outer", spaces: [], trivia: [], rules: [
			("root", "root", true, Syntax {
				Fragment(tag: "x", "a")
				Rule("Inner", "root")
				Fragment(tag: "x")
			}),
		])
		let inner: SpelluGrammar = .init(name: "Inner", spaces: [], trivia: [], rules: [
			("root", "root", true, Syntax {
				Optional { Fragment(tag: "x") }
				Fragment(tag: "x", "b")
				Fragment(tag: "x")
			}),
		])
		let parser: Spellu = try Spellu(engine: engine).input(outer, inner)
		#expect(try parser.parse("abba").string == "abba")
		#expect(throws: SpelluError.self) { try parser.parse("aabba") }
	}

	@Test(arguments: engines)
	func 原文をケース無視で参照し出力範囲を保持する(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Fragment(label: "capture", tag: "x", "K")
			Fragment(":")
			Fragment(tag: "x").as(label: "reference")
		}
		let node: SourceNode = try parser.parse("K:k", strategy: .compact)
		#expect(node.parts.map(\.string) == ["K", "k"])
		#expect(node.parts.map(\.label) == ["capture", "reference"])
		#expect(throws: SpelluError.self) { try parser.parse("K:x") }
	}

	@Test(arguments: engines)
	func 未記録は失敗しOptionalとChoiceで回復できる(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Optional { Fragment(tag: "missing") }
			ChoiceOf {
				Fragment(tag: "missing")
				Fragment("a")
			}
		}
		#expect(try parser.parse("a").string == "a")
	}

	@Test(arguments: engines)
	func 空文字列を記録し上書きできる(engine: Spellu.Engine) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Fragment(tag: "x", "a")
			Fragment(tag: "x")
			Fragment(tag: "x") { "b".repeat(0...0) }
			Fragment(tag: "x")
			Fragment("!")
		}
		#expect(try parser.parse("aa!").string == "aa!")
	}

	@Test(arguments: engines)
	func 失敗した分岐とOptionalの記録を巻き戻す(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: []) {
			Fragment(tag: "x", "a")
			Optional {
				Fragment(tag: "x", "b")
				Fragment("!")
			}
			ChoiceOf {
				Sequence { Fragment(tag: "x", "b"); Fragment("?") }
				Fragment("b")
			}
			Fragment(tag: "x")
		}
		#expect(try parser.parse("aba").string == "aba")
	}

	@Test(arguments: engines)
	func Tokenは空白を除いた範囲を記録し参照前の空白も許す(
		engine: Spellu.Engine,
	) throws {
		let parser: Spellu = try Spellu(engine: engine).input(spaces: [.space]) {
			Token(tag: "x") { "=".repeat(1...) }
			Token(":")
			Token(tag: "x")
		}
		#expect(try parser.parse(" == : ==").string == "== : ==")
		#expect(throws: SpelluError.self) { try parser.parse("== : =") }
	}

	@Test(arguments: engines)
	func 同文法の呼び出しとAtomicの記録を呼び出し後も参照する(
		engine: Spellu.Engine,
	) throws {
		let grammar: SpelluGrammar = .init(name: "G", spaces: [], trivia: [], rules: [
			("root", "root", true, Syntax {
				SyntaxIR.ruleref(nil, "capture")
				Fragment(tag: "x")
				Atomic { Fragment(tag: "x", "b") }
				Fragment(tag: "x")
			}),
			("capture", "capture", false, Syntax { Fragment(tag: "x", "a") }),
		])
		let parser: Spellu = try Spellu(engine: engine).input(grammar)
		#expect(try parser.parse("aabb").string == "aabb")
		#expect(try parser.parse("aabb").string == "aabb")
	}
}

