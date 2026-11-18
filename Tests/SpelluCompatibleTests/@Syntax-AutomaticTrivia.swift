// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行7件、一致7件、差異0件。
// ✅ 読み始めの位置が違う反復の回で同じ木でもTriviaを取り違えない：I=S=H 成功（自動Trivia）
// ✅ 乱数の文法で見つかった差を固定する：I=S=H 成功（asisと自動Trivia）
// ✅ 構文Triviaの読み方が複数でも本文は一意に決まる：I=S=H 成功
// ✅ 読み方が複数なら先頭から順に各構文Triviaが最も長いものを採る：I=S=H 成功（宣言順に依存しない）
// ✅ 読み方の数が多くても作業量が増えない：I=S=H 成功
// ✅ 一回の読み飛ばしの中で隣接する範囲はまとめる：I=S=H 成功
// ✅ 幅0の字句をはさんだ読み飛ばしはまとめない：I=S=H 成功
// 一覧ここまで

import Spellu


@Suite struct SyntaxAutomaticTriviaTests {

	/// 自動Triviaを集めるエンジン。
	static let engines: [Spellu.Engine] = [.interpreter, .sakuya, .hoori]

	/// 反復の最初の回は、位置3から空白を読んで位置4の空の字句を読む。
	/// ChoiceOfの別の枝（Sequence＋明示Trivia）から位置4で始まる回も、同じ木になる。
	/// 読み始めの位置が違うので、Triviaは別にしておかなければならない。
	/// spacesで読んだ空白は収集しない。
	@Test func 読み始めの位置が違う反復の回で同じ木でもTriviaを取り違えない() throws {
		let rule = Syntax {
			Token("a")
			ChoiceOf {
				Token(label: "A", "a")
				Sequence {
					Token("a")
					Trivia
				}
			}
			Repeat {
				Token(label: "E") { "x".repeat(0...1) }
			}
		}

		let source: String
		= "a a "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
				Tree(label: "A", "a")
				Tree(label: "E", "")
				Tree(label: "E", "")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "E", "")
				Tree(label: "E", "")
			},
		)

		try compatibleTriviaTest(
			Self.engines,
			rule: rule,
			source: source,
			trivia: [],
		)

		// 構文Triviaは途中で止まれるので、空の字句が読める位置を空白の後に限る。
		let empty: SyntaxIR
		= .word(
			"E",
			.alternative([.string(" ")], amount: .zeroOrMore),
			[""],
			caseInsensitive: false,
		)

		try compatibleTriviaTest(
			Self.engines,
			grammar: Self.grammar(
				trivia: [("space", " ")],
				Syntax {
					Token("a")
					ChoiceOf {
						Token(label: "A", "a")
						Sequence {
							Token("a")
							Trivia
						}
					}
					Repeat { [empty] }
				},
			),
			source: source,
			trivia: [1..<2, 3..<4],
		)
	}

	@Test func 乱数の文法で見つかった差を固定する() throws {
		var fuzzer: GrammarFuzzer
		= .init(seed: 17684)

		let grammar: SpelluGrammar
		= fuzzer.grammar()

		var roots: [SourceNode] = []

		for engine in Self.engines {
			let parser: Spellu = try Spellu(engine: engine).input(grammar)
			let tree: SourceTree = try parser.parse(
				.temporary("a a "), method: .whole, strategy: .asis,
			)
			#expect(tree.trivia.isEmpty, "\(engine)")
			roots.append(tree.root)
		}

		#expect(roots.allSatisfy { $0 == roots[0] })
	}

	@Test(arguments: engines)
	func 構文Triviaの読み方が複数でも本文は一意に決まる(
		engine: Spellu.Engine,
	) throws {
		let grammar: SpelluGrammar = .init(
			name: "S", spaces: [.space], trivia: ["short", "long"],
			rules: [
				("root", "root", true, Syntax { Token("a") }),
				("short", .none, false, Syntax { Fragment("#") }),
				("long", .none, false, Syntax { Fragment("##") }),
			],
		)
		let parser: Spellu = try Spellu(engine: engine).input(grammar)
		let tree: SourceTree = try parser.parse(.temporary(" ## # a "))

		#expect(tree.root.range == 6..<7)
		#expect(tree.trivia.map(\.range) == [1..<3, 4..<5])
		#expect(tree.trivia.map(\.label) == ["#trivia", "#trivia"])
	}

	@Test func 読み方が複数なら先頭から順に各構文Triviaが最も長いものを採る() throws {
		let rule = Syntax { Token("a") }

		for trivia: [(String, String)] in [
			[("short", "#"), ("long", "# #")],
			[("long", "# #"), ("short", "#")],
		] {
			let grammar: SpelluGrammar
			= Self.grammar(spaces: [.space], trivia: trivia, rule)

			try compatibleTriviaTest(
				Self.engines,
				grammar: grammar,
				source: "# # a",
				trivia: [0..<3],
			)

			try compatibleTriviaTest(
				Self.engines,
				grammar: grammar,
				source: "# # # a",
				trivia: [0..<3, 4..<5],
			)
		}
	}

	@Test func 読み方の数が多くても作業量が増えない() throws {
		let source: String
		= String(repeating: "#", count: 64) + "a"

		try compatibleTriviaTest(
			Self.engines,
			grammar: Self.grammar(
				trivia: [("short", "#"), ("long", "##")],
				Syntax { Token("a") },
			),
			source: source,
			trivia: [0..<64],
		)
	}

	@Test func 一回の読み飛ばしの中で隣接する範囲はまとめる() throws {
		try compatibleTriviaTest(
			Self.engines,
			grammar: Self.grammar(
				trivia: [("hash", "#"), ("percent", "%")],
				Syntax { Token("a") },
			),
			source: "#%#a",
			trivia: [0..<3],
		)
	}

	/// 空の字句は、次の文字が `#` や `b` だと失敗するので位置2でだけ読める。
	@Test func 幅0の字句をはさんだ読み飛ばしはまとめない() throws {
		let empty: SyntaxIR
		= .word(
			.none,
			.alternative([.string("#"), .string("b")], amount: .zeroOrMore),
			[""],
			caseInsensitive: false,
		)

		try compatibleTriviaTest(
			Self.engines,
			grammar: Self.grammar(
				trivia: [("hash", "#"), ("percent", "%")],
				Syntax {
					Token("a")
					[empty]
					Token("b")
				},
			),
			source: "a#%b",
			trivia: [1..<2, 2..<3],
		)
	}

	/// 構文Triviaの規則を持つ文法。規則 `$` が入口になる。
	private static func grammar(
		spaces: [SpacePattern] = [],
		trivia: [(name: String, text: String)],
		_ rule: Syntax,
	) -> SpelluGrammar {
		let rules: [(name: String, label: Label, expose: Bool, syntax: Syntax)]
		= trivia.map { item in
			(item.name, .none, false, Syntax { Fragment(item.text) })
		}

		return .init(
			name: "_",
			spaces: spaces,
			trivia: trivia.map(\.name),
			rules: [("$", .none, true, rule)] + rules,
		)
	}

}
