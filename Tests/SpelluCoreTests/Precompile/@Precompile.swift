import SpelluLex
@testable import SpelluCore


// 対象: precompileへ未加工のルールを渡し、文法全体のリテラルを
// フラットに分割した出力を、expectedの文法と構造・属性ごとに比較する。
@Suite struct PrecompileTests {

	@Test func 空のルール配列は空のまま返す() {
		let input: [SpelluRule] = []
		let expected: [SpelluRule] = []

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func 共通接頭辞と残りの接頭辞をSequence内のFragmentへ分割する() {
		let input: [SpelluRule] = [
			.init(name: "left", syntax: Syntax { Fragment("abcd") }),
			.init(name: "right", syntax: Syntax { Fragment("abef") }),
			.init(name: "suffix", syntax: Syntax { Fragment("cdx") }),
		]
		let expected: [SpelluRule] = [
			.init(name: "left", syntax: Syntax {
				Sequence { Fragment("ab"); Fragment("cd") }
			}),
			.init(name: "right", syntax: Syntax {
				Sequence { Fragment("ab"); Fragment("ef") }
			}),
			.init(name: "suffix", syntax: Syntax {
				Sequence { Fragment("cd"); Fragment("x") }
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func Tokenを先頭のTokenと後続のFragmentへ分割する() {
		let input: [SpelluRule] = [
			.init(name: "long", label: "rule", expose: true, syntax: Syntax {
				Token(label: "literal", "abc")
			}),
			.init(name: "short", syntax: Syntax { Fragment("a") }),
		]
		let expected: [SpelluRule] = [
			.init(name: "long", label: "rule", expose: true, syntax: Syntax {
				Sequence(label: "literal") { Token("a"); Fragment("bc") }
			}),
			.init(name: "short", syntax: Syntax { Fragment("a") }),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func Fragmentを全てFragmentのSequenceへ分割する() {
		let input: [SpelluRule] = [
			.init(name: "long", syntax: Syntax { Fragment(label: "literal", "abc") }),
			.init(name: "short", syntax: Syntax { Fragment("a") }),
		]
		let expected: [SpelluRule] = [
			.init(name: "long", syntax: Syntax {
				Sequence(label: "literal") { Fragment("a"); Fragment("bc") }
			}),
			.init(name: "short", syntax: Syntax { Fragment("a") }),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func 同一の固定字句が複数あっても分割しない() {
		let input: [SpelluRule] = [
			.init(name: "first", syntax: Syntax {
				SyntaxIR.token("first", .string("abc"), spacious: false)
			}),
			.init(name: "second", syntax: Syntax {
				SyntaxIR.token("second", .string("abc"), spacious: true)
			}),
		]
		let expected: [SpelluRule] = [
			.init(name: "first", syntax: Syntax {
				SyntaxIR.token("first", .string("abc"), spacious: false)
			}),
			.init(name: "second", syntax: Syntax {
				SyntaxIR.token("second", .string("abc"), spacious: true)
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func 分割した後半も接頭辞が重なる限り再分割する() {
		let input: [SpelluRule] = [
			.init(name: "short", syntax: Syntax { Fragment("a") }),
			.init(name: "long", syntax: Syntax { Fragment("aaaa") }),
		]
		let expected: [SpelluRule] = [
			.init(name: "short", syntax: Syntax { Fragment("a") }),
			.init(name: "long", syntax: Syntax {
				Sequence {
					Fragment("a"); Fragment("a"); Fragment("a"); Fragment("a")
				}
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func UnicodeScalarの共通接頭辞で分割する() {
		let input: [SpelluRule] = [
			.init(name: "short", syntax: Syntax { Fragment("日e\u{301}") }),
			.init(name: "long", syntax: Syntax { Fragment("日e\u{301}本") }),
		]
		let expected: [SpelluRule] = [
			.init(name: "short", syntax: Syntax { Fragment("日e\u{301}") }),
			.init(name: "long", syntax: Syntax {
				Sequence { Fragment("日e\u{301}"); Fragment("本") }
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func 大小文字を無視した共通接頭辞を折り畳んで分割する() {
		let input: [SpelluRule] = [
			.init(name: "short", syntax: Syntax { Fragment("Σa", ignoresCase: true) }),
			.init(name: "long", syntax: Syntax { Fragment("ςab", ignoresCase: true) }),
		]
		let expected: [SpelluRule] = [
			.init(name: "short", syntax: Syntax { Fragment("Σa", ignoresCase: true) }),
			.init(name: "long", syntax: Syntax {
				Sequence {
					Fragment("σa", ignoresCase: true)
					Fragment("b", ignoresCase: true)
				}
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func 異なる大小文字の照合条件の字句は互いに分割しない() {
		let input: [SpelluRule] = [
			.init(name: "sensitive", syntax: Syntax {
				SyntaxIR.token(.none, .string("A", caseInsensitive: false),
					spacious: false)
			}),
			.init(name: "insensitive", syntax: Syntax {
				SyntaxIR.token(.none, .string("ab", caseInsensitive: true),
					spacious: false)
			}),
		]
		let expected: [SpelluRule] = [
			.init(name: "sensitive", syntax: Syntax {
				SyntaxIR.token(.none, .string("A", caseInsensitive: false),
					spacious: false)
			}),
			.init(name: "insensitive", syntax: Syntax {
				SyntaxIR.token(.none, .string("ab", caseInsensitive: true),
					spacious: false)
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func 構文の入れ子を保ちながら内部の字句を展開する() {
		let input: [SpelluRule] = [
			.init(name: "nested", syntax: Syntax {
				Sequence(label: "group") {
					Atomic {
						Optional {
							Repeat(1...3, behavior: .reluctant) {
								ChoiceOf { Fragment("abc"); Fragment("a") }
							}
						}
					}
				}
			}),
		]
		let expected: [SpelluRule] = [
			.init(name: "nested", syntax: Syntax {
				Sequence(label: "group") {
					Atomic {
						Optional {
							Repeat(1...3, behavior: .reluctant) {
								ChoiceOf {
									Sequence { Fragment("a"); Fragment("bc") }
									Fragment("a")
								}
							}
						}
					}
				}
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func AnyOfとListとEnclosureの構造と属性を保持する() {
		let input: [SpelluRule] = [
			.init(name: "choice", syntax: Syntax {
				AnyOf {
					Branch(.high) { Fragment("abc") }
					Branch(.low) { Fragment("a") }
				}
			}),
			.init(name: "list", syntax: Syntax {
				List(1...3, lastSeparator: .allow) {
					Fragment("abc")
				} separator: { Fragment(",") }
			}),
			.init(name: "enclosure", syntax: Syntax {
				Enclosure("{", "}") { Fragment("abc") }
			}),
		]
		let expected: [SpelluRule] = [
			.init(name: "choice", syntax: Syntax {
				AnyOf {
					Branch(.high) { Sequence { Fragment("a"); Fragment("bc") } }
					Branch(.low) { Fragment("a") }
				}
			}),
			.init(name: "list", syntax: Syntax {
				List(1...3, lastSeparator: .allow) {
					Sequence { Fragment("a"); Fragment("bc") }
				} separator: { Fragment(",") }
			}),
			.init(name: "enclosure", syntax: Syntax {
				Enclosure("{", "}") { Sequence { Fragment("a"); Fragment("bc") } }
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func ルール本体のリテラルを分割し参照命令と外部文法を保持する() {
		let input: [SpelluRule] = [
			.init(name: "root", syntax: Syntax {
				Fragment("a")
				SyntaxIR.ruleref(nil, "local")
				SyntaxIR.ruleref("Child", "child")
			}),
			.init(name: "local", syntax: Syntax { Fragment("ab") }),
		]
		let expected: [SpelluRule] = [
			.init(name: "root", syntax: Syntax {
				Fragment("a")
				SyntaxIR.ruleref(nil, "local")
				SyntaxIR.ruleref("Child", "child")
			}),
			.init(name: "local", syntax: Syntax {
				Sequence { Fragment("a"); Fragment("b") }
			}),
		]

		let result: [SpelluRule] = SpelluGrammar.precompile(input)

		#expect(result == expected)
	}

	@Test func 再適用してもSequenceを重ねず分割片とIDを保持する() {
		let input: [SpelluRule] = [
			.init(name: "long", syntax: Syntax { Token(label: "long", "abc") }),
			.init(name: "short", syntax: Syntax { Fragment("a") }),
		]
		let expected: [SpelluRule] = [
			.init(name: "long", syntax: Syntax {
				Sequence(label: "long") { Token("a"); Fragment("bc") }
			}),
			.init(name: "short", syntax: Syntax { Fragment("a") }),
		]
		let first: [SpelluRule] = SpelluGrammar.precompile(input)

		let result: [SpelluRule] = SpelluGrammar.precompile(first)

		#expect(result == expected)
		#expect(result == first)
	}

}

