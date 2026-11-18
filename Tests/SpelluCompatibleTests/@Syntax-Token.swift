// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行24件、一致24件、差異0件。
// ✅ ラベルのないTokenの文字列が一致する：I=S=H 成功
// ✅ ラベル付きTokenの文字列が一致する：I=S=H 成功
// ✅ 一時ラベル付きTokenのcompact出力を比較する：I=S=H 成功
// ✅ TokenのBuilder内の複数要素を一つの字句として出力する：I=S=H 成功
// ✅ Tokenの本文に含まれる空白を保持する：I=S=H 成功
// ✅ Tokenで大小文字を区別して失敗する：I=S=H 不一致
// ✅ TokenでASCIIの大小文字を無視して原文を保持する：I=S=H 成功
// ✅ TokenでUnicodeの大小文字を無視して原文を保持する：I=S=H 成功
// ✅ TokenでUnicodeの十進数字を読む：I=S=H 成功
// ✅ TokenのBuilder内の途中失敗位置を比較する：I=S=H 不一致
// ✅ Token内部のChoiceOfは後続のために別候補へ戻る：I=S=H 成功
// ✅ Token内部の反復が上限の回数に一致する：I=S=H 成功
// ✅ Token内部の反復が下限に届かない：I=S=H 不一致
// ✅ 本文が空のTokenの出力を比較する：I=S=H 成功
// ✅ 空文字列のTokenの結果を比較する：I=S=H 成功
// ✅ Tokenが先頭で不一致になる：I=S=H 不一致
// ✅ Tokenが文字列の途中でEOFになる：I=S=H 不一致
// ✅ Tokenの後に余分な入力が残る：I=S=H 不一致
// ✅ Tokenで改行そのものを読む：I=S=H 成功
// ✅ 先頭に空白があるTokenの結果を比較する：I=S=H 成功
// ✅ Tokenの末尾の空白を本文の範囲へ含めない：I=S=H 成功
// ✅ 隣接するTokenの間の空白を読み飛ばす：I=S=H 成功
// ✅ Tokenの後のFragmentは空白を読み飛ばさない：I=S=H 不一致
// ✅ Token内部の要素間では空白を読み飛ばさない：I=S=H 不一致
// 一覧ここまで

import Spellu


// TokenのCompatible Tests。
// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct SyntaxTokenTests {

	@Test func ラベルのないTokenの文字列が一致する() throws {
		let rule = Syntax {
			Token("a")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ラベル付きTokenの文字列が一致する() throws {
		let rule = Syntax {
			Token(label: "A", "a")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 一時ラベル付きTokenのcompact出力を比較する() throws {
		let rule = Syntax {
			Token(label: "#value", "a")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#value", "a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func TokenのBuilder内の複数要素を一つの字句として出力する() throws {
		let rule = Syntax {
			Token(label: "pair") {
				"a"
				"b"
			}
		}

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "pair", "ab")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", "ab")
			},
		)
	}

	@Test func Tokenの本文に含まれる空白を保持する() throws {
		let rule = Syntax {
			Token(label: "value", "a b")
		}

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "value", "a b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "value", "a b")
			},
		)
	}

	@Test func Tokenで大小文字を区別して失敗する() throws {
		let rule = Syntax {
			Token(label: "value", "swift", ignoresCase: false)
		}

		let source: String
		= "Swift"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.literal("swift")],
			),
		)
	}

	@Test func TokenでASCIIの大小文字を無視して原文を保持する() throws {
		let rule = Syntax {
			Token(label: "value", "swift", ignoresCase: true)
		}

		let source: String
		= "SwIfT"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "value", "SwIfT")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "value", "SwIfT")
			},
		)
	}

	@Test func TokenでUnicodeの大小文字を無視して原文を保持する() throws {
		let rule = Syntax {
			Token(label: "value", "Σ", ignoresCase: true)
		}

		let source: String
		= "ς"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "value", "ς")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "value", "ς")
			},
		)
	}

	@Test func TokenでUnicodeの十進数字を読む() throws {
		let rule = Syntax {
			Token(label: "number") {
				Character.digit.repeat(1...)
			}
		}

		let source: String
		= "0９٠۹९𝟠"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "number", "0９٠۹९𝟠")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "number", "0９٠۹९𝟠")
			},
		)
	}

	@Test func TokenのBuilder内の途中失敗位置を比較する() throws {
		let rule = Syntax {
			Token {
				"ab"
				"c"
			}
		}

		let source: String
		= "abX"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("c")],
			),
		)
	}

	@Test func Token内部のChoiceOfは後続のために別候補へ戻る() throws {
		let rule = Syntax {
			Token(label: "value") {
				ChoiceOf {
					"ab"
					"a"
				}
				"b"
			}
		}

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "value", "ab")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "value", "ab")
			},
		)
	}

	@Test func Token内部の反復が上限の回数に一致する() throws {
		let rule = Syntax {
			Token(label: "value") {
				"a".repeat(2...3)
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "value", "aaa")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "value", "aaa")
			},
		)
	}

	@Test func Token内部の反復が下限に届かない() throws {
		let rule = Syntax {
			Token(label: "value") {
				"a".repeat(2...3)
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("a")],
			),
		)
	}

	@Test func 本文が空のTokenの出力を比較する() throws {
		let rule = Syntax {
			Token(label: "empty") {
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
				Tree(label: "empty", "")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "empty", "")
			},
		)
	}

	@Test func 空文字列のTokenの結果を比較する() throws {
		let rule = Syntax {
			Token(label: "empty", "")
		}

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "empty", "")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "empty", "")
			},
		)
	}

	@Test func Tokenが先頭で不一致になる() throws {
		let rule = Syntax {
			Token("a")
		}

		let source: String
		= "x"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.literal("a")],
			),
		)
	}

	@Test func Tokenが文字列の途中でEOFになる() throws {
		let rule = Syntax {
			Token("abc")
		}

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("c")],
			),
		)
	}

	@Test func Tokenの後に余分な入力が残る() throws {
		let rule = Syntax {
			Token(label: "value", "a")
		}

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.eos],
			),
		)
	}

	@Test func Tokenで改行そのものを読む() throws {
		let rule = Syntax {
			Token(label: "newline", "\n")
		}

		let source: String
		= "\n"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "newline", "\n")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "newline", "\n")
			},
		)
	}

	@Test func 先頭に空白があるTokenの結果を比較する() throws {
		let rule = Syntax {
			Token(label: "A", "a")
		}

		let source: String
		= " a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: "a",
			asis: Tree(label: "$", "a") {
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", "a") {
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Tokenの末尾の空白を本文の範囲へ含めない() throws {
		let rule = Syntax {
			Token(label: "A", "a")
		}

		let source: String
		= "a "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: "a",
			asis: Tree(label: "$", "a") {
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", "a") {
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 隣接するTokenの間の空白を読み飛ばす() throws {
		let rule = Syntax {
			Token(label: "A", "a")
			Token(label: "B", "b")
		}

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func Tokenの後のFragmentは空白を読み飛ばさない() throws {
		let rule = Syntax {
			Token(label: "A", "a")
			Fragment(label: "B", "b")
		}

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("b")],
			),
		)
	}

	@Test func Token内部の要素間では空白を読み飛ばさない() throws {
		let rule = Syntax {
			Token {
				"a"
				"b"
			}
		}

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("b")],
			),
		)
	}

}
