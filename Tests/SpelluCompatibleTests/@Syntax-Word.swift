// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行29件、一致29件、差異0件。
// ✅ ラベルのないWordが一致する：I=S=H 成功
// ✅ ラベル付きWordが一致する：I=S=H 成功
// ✅ 一時ラベル付きWordのcompact出力を比較する：I=S=H 成功
// ✅ 可変長引数で指定したWordの後続の語が一致する：I=S=H 成功
// ✅ 配列で指定したWordの後続の語が一致する：I=S=H 成功
// ✅ Wordの語配列に重複があっても一致する：I=S=H 成功
// ✅ Wordの語集合外の入力を比較する：I=S=H 不一致
// ✅ Wordの大小文字を区別した語の照合を比較する：I=S=H 不一致
// ✅ Wordの語とパターンの両方で大小文字を無視する：I=S=H 成功
// ✅ Wordの語の大小文字指定はパターンの指定を変えない：I=S=H 不一致
// ✅ WordでUnicodeの大小文字を無視し原文を保持する：I=S=H 成功
// ✅ Wordで日本語と絵文字の原文を保持する：I=S=H 成功
// ✅ Wordの先頭の空白を読み飛ばす：I=S=H 成功
// ✅ Wordの末尾の空白を本文の範囲へ含めない：I=S=H 成功
// ✅ Wordの字句パターンが語の接頭辞を越えて読む場合を比較する：I=S=H 不一致
// ✅ 固定パターンのWordに接頭辞として一致して後続へ進む：I=S=H 成功
// ✅ Wordの後の区切りを別の字句として読む：I=S=H 成功
// ✅ 同じパターンのWordを連続して読む：I=S=H 成功
// ✅ Wordの内部パターンが途中でEOFになる：I=S=H 不一致
// ✅ Wordの内部のChoiceOfと語の照合を比較する：I=S=H 不一致
// ✅ Wordの任意末尾の部分一致を後続の字句へ残す：I=S=H 成功
// ✅ 空の語集合のWordを空入力で比較する：I=S=H 不一致
// ✅ 空文字列を語に持つWordと空のBuilderを比較する：I=S=H 成功
// ✅ 空文字列を語に持つWordと空リテラルを比較する：I=S=H 成功
// ✅ Wordと通常Tokenで語集合外の入力を選ぶ：I=S=H 成功
// ✅ Wordと通常Tokenの両方が成功する場合を比較する：I=S=H 曖昧
// ✅ 同じ語のWord候補を後続の字句で区別する：I=S=H 成功
// ✅ Wordの複数キーワードを重複なく期待する：I=S=H 不一致
// ✅ Wordのパターンが途中で失敗してもキーワードを期待する：I=S=H 不一致
// 一覧ここまで

import Spellu


// WordのCompatible Tests。
// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct SyntaxWordTests {

	@Test func ラベルのないWordが一致する() throws {
		let rule = Syntax {
			Word("if") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "if"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("if")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ラベル付きWordが一致する() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "if"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
			},
		)
	}

	@Test func 一時ラベル付きWordのcompact出力を比較する() throws {
		let rule = Syntax {
			Word(label: "#keyword", "if") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "if"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#keyword", "if")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 可変長引数で指定したWordの後続の語が一致する() throws {
		let rule = Syntax {
			Word(label: "keyword", "if", "else") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "else"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "else")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "else")
			},
		)
	}

	@Test func 配列で指定したWordの後続の語が一致する() throws {
		let rule = Syntax {
			Word(label: "keyword", ["if", "else"]) {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "else"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "else")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "else")
			},
		)
	}

	@Test func Wordの語配列に重複があっても一致する() throws {
		let rule = Syntax {
			Word(label: "keyword", ["if", "else", "if"]) {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "if"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
			},
		)
	}

	@Test func Wordの語集合外の入力を比較する() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "while"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 5,
				line: 1,
				column: 6,
				expects: [.literal("if")],
			),
		)
	}

	@Test func Wordの大小文字を区別した語の照合を比較する() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				ASCII.word.repeat(1...).ignoresCase()
			}
		}

		let source: String
		= "IF"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("if")],
			),
		)
	}

	@Test func Wordの語とパターンの両方で大小文字を無視する() throws {
		let rule = Syntax {
			Word(label: "keyword", "if", caseInsensitive: true) {
				ASCII.word.repeat(1...).ignoresCase()
			}
		}

		let source: String
		= "IF"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "IF")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "IF")
			},
		)
	}

	@Test func Wordの語の大小文字指定はパターンの指定を変えない() throws {
		let rule = Syntax {
			Word(label: "keyword", "if", caseInsensitive: true) {
				"if"
			}
		}

		let source: String
		= "IF"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.literal("if")],
			),
		)
	}

	@Test func WordでUnicodeの大小文字を無視し原文を保持する() throws {
		let rule = Syntax {
			Word(label: "keyword", "Σ", caseInsensitive: true) {
				Character.all.repeat(1...)
			}
		}

		let source: String
		= "ς"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "ς")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "ς")
			},
		)
	}

	@Test func Wordで日本語と絵文字の原文を保持する() throws {
		let rule = Syntax {
			Word(label: "keyword", "日本🙂") {
				Character.all.repeat(1...)
			}
		}

		let source: String
		= "日本🙂"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "日本🙂")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "日本🙂")
			},
		)
	}

	@Test func Wordの先頭の空白を読み飛ばす() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "  if"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: "if",
			asis: Tree(label: "$", "if") {
				Tree(label: "keyword", "if")
			},
			compact: Tree(label: "$", "if") {
				Tree(label: "keyword", "if")
			},
		)
	}

	@Test func Wordの末尾の空白を本文の範囲へ含めない() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "if "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: "if",
			asis: Tree(label: "$", "if") {
				Tree(label: "keyword", "if")
			},
			compact: Tree(label: "$", "if") {
				Tree(label: "keyword", "if")
			},
		)
	}

	@Test func Wordの字句パターンが語の接頭辞を越えて読む場合を比較する() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "iffy"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 4,
				line: 1,
				column: 5,
				expects: [.literal("if")],
			),
		)
	}

	@Test func 固定パターンのWordに接頭辞として一致して後続へ進む() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				"if"
			}
			Fragment(label: "tail", "fy")
		}

		let source: String
		= "iffy"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
				Tree(label: "tail", "fy")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
				Tree(label: "tail", "fy")
			},
		)
	}

	@Test func Wordの後の区切りを別の字句として読む() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				ASCII.word.repeat(1...)
			}
			Fragment(";")
		}

		let source: String
		= "if;"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
				Tree(";")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
			},
		)
	}

	@Test func 同じパターンのWordを連続して読む() throws {
		let rule = Syntax {
			Word(label: "first", "if") {
				ASCII.word.repeat(1...)
			}
			Word(label: "second", "else") {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "if else"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "first", "if")
				Tree(label: "second", "else")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "first", "if")
				Tree(label: "second", "else")
			},
		)
	}

	@Test func Wordの内部パターンが途中でEOFになる() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				"if"
			}
		}

		let source: String
		= "i"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("if")],
			),
		)
	}

	@Test func Wordの内部のChoiceOfと語の照合を比較する() throws {
		let rule = Syntax {
			Word(label: "keyword", "iffy") {
				ChoiceOf {
					"if"
					"iffy"
				}
			}
		}

		let source: String
		= "iffy"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("iffy")],
			),
		)
	}

	@Test func Wordの任意末尾の部分一致を後続の字句へ残す() throws {
		let rule = Syntax {
			Word(label: "keyword", "if") {
				"if"
				Optional {
					"fy"
				}
			}
			Fragment(label: "tail", "f!")
		}

		let source: String
		= "iff!"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
				Tree(label: "tail", "f!")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "if")
				Tree(label: "tail", "f!")
			},
		)
	}

	@Test func 空の語集合のWordを空入力で比較する() throws {
		let rule = Syntax {
			Word(label: "keyword", []) {
			}
		}

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [],
			),
		)
	}

	@Test func 空文字列を語に持つWordと空のBuilderを比較する() throws {
		let rule = Syntax {
			Word(label: "keyword", "") {
			}
		}

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "")
			},
		)
	}

	@Test func 空文字列を語に持つWordと空リテラルを比較する() throws {
		let rule = Syntax {
			Word(label: "keyword", "") {
				""
			}
		}

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "keyword", "")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "keyword", "")
			},
		)
	}

	@Test func Wordと通常Tokenで語集合外の入力を選ぶ() throws {
		let rule = Syntax {
			AnyOf {
				Word(label: "keyword", "if") {
					ASCII.word.repeat(1...)
				}
				Token(label: "identifier") {
					ASCII.word.repeat(1...)
				}
			}
		}

		let source: String
		= "while"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "identifier", "while")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "identifier", "while")
			},
		)
	}

	@Test func Wordと通常Tokenの両方が成功する場合を比較する() throws {
		let rule = Syntax {
			AnyOf {
				Word(label: "keyword", "if") {
					"if"
				}
				Token(label: "identifier", "if")
			}
		}

		let source: String
		= "if"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			error: .ambiguousPath(precedence: 0),
		)
	}

	@Test func 同じ語のWord候補を後続の字句で区別する() throws {
		let rule = Syntax {
			AnyOf {
				Sequence {
					Word(label: "left", "if") {
						"if"
					}
					Fragment("!")
				}
				Sequence {
					Word(label: "right", "if") {
						"if"
					}
					Fragment("?")
				}
			}
		}

		let source: String
		= "if?"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#and", "if?") {
					Tree(label: "right", "if")
					Tree("?")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "right", "if")
			},
		)
	}


	@Test func Wordの複数キーワードを重複なく期待する() throws {
		let rule = Syntax {
			Word(label: "keyword", ["if", "else", "if"]) {
				ASCII.word.repeat(1...)
			}
		}

		let source: String
		= "while"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 5,
				line: 1,
				column: 6,
				expects: [.literal("else"), .literal("if")],
			),
		)
	}

	@Test func Wordのパターンが途中で失敗してもキーワードを期待する() throws {
		let rule = Syntax {
			Word(label: "keyword", ["if", "else"]) {
				ASCII.word.repeat(2...)
			}
		}

		let source: String
		= "i!"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("else"), .literal("if")],
			),
		)
	}

}
