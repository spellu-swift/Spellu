// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行25件、一致25件、差異0件。
// ✅ ラベルのないFragmentの文字列が一致する：I=S=H 成功
// ✅ ラベル付きFragmentの文字列が一致する：I=S=H 成功
// ✅ 一時ラベル付きFragmentのcompact出力を比較する：I=S=H 成功
// ✅ FragmentのBuilder内の複数要素を一つの字句として出力する：I=S=H 成功
// ✅ Fragmentの本文に含まれる空白を保持する：I=S=H 成功
// ✅ Fragmentで大小文字を区別して失敗する：I=S=H 不一致
// ✅ FragmentでASCIIの大小文字を無視して原文を保持する：I=S=H 成功
// ✅ FragmentでUnicodeの大小文字を無視して原文を保持する：I=S=H 成功
// ✅ FragmentでUnicodeの十進数字を読む：I=S=H 成功
// ✅ FragmentのBuilder内の途中失敗位置を比較する：I=S=H 不一致
// ✅ Fragment内部のChoiceOfは後続のために別候補へ戻る：I=S=H 成功
// ✅ Fragment内部の反復が上限の回数に一致する：I=S=H 成功
// ✅ Fragment内部の反復が下限に届かない：I=S=H 不一致
// ✅ 本文が空のFragmentの出力を比較する：I=S=H 成功
// ✅ 空文字列のFragmentの結果を比較する：I=S=H 成功
// ✅ Fragmentが先頭で不一致になる：I=S=H 不一致
// ✅ Fragmentが文字列の途中でEOFになる：I=S=H 不一致
// ✅ Fragmentの後に余分な入力が残る：I=S=H 不一致
// ✅ Fragmentで改行そのものを読む：I=S=H 成功
// ✅ 先頭に空白があるFragmentの結果を比較する：I=S=H 不一致
// ✅ Fragmentの末尾の空白を本文の範囲へ含めない：I=S=H 成功
// ✅ 隣接するFragmentを空白なしで読む：I=S=H 成功
// ✅ 隣接するFragmentの間の空白で失敗する：I=S=H 不一致
// ✅ Fragmentで要素間の空白を明示的に読む：I=S=H 成功
// ✅ Fragmentの後のTokenは空白を読み飛ばす：I=S=H 成功
// 一覧ここまで

import Spellu


// FragmentのCompatible Tests。
// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct SyntaxFragmentTests {

	@Test func ラベルのないFragmentの文字列が一致する() throws {
		let rule = Syntax {
			Fragment("a")
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

	@Test func ラベル付きFragmentの文字列が一致する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
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

	@Test func 一時ラベル付きFragmentのcompact出力を比較する() throws {
		let rule = Syntax {
			Fragment(label: "#value", "a")
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

	@Test func FragmentのBuilder内の複数要素を一つの字句として出力する() throws {
		let rule = Syntax {
			Fragment(label: "pair") {
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

	@Test func Fragmentの本文に含まれる空白を保持する() throws {
		let rule = Syntax {
			Fragment(label: "value", "a b")
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

	@Test func Fragmentで大小文字を区別して失敗する() throws {
		let rule = Syntax {
			Fragment(label: "value", "swift", ignoresCase: false)
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

	@Test func FragmentでASCIIの大小文字を無視して原文を保持する() throws {
		let rule = Syntax {
			Fragment(label: "value", "swift", ignoresCase: true)
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

	@Test func FragmentでUnicodeの大小文字を無視して原文を保持する() throws {
		let rule = Syntax {
			Fragment(label: "value", "Σ", ignoresCase: true)
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

	@Test func FragmentでUnicodeの十進数字を読む() throws {
		let rule = Syntax {
			Fragment(label: "number") {
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

	@Test func FragmentのBuilder内の途中失敗位置を比較する() throws {
		let rule = Syntax {
			Fragment {
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

	@Test func Fragment内部のChoiceOfは後続のために別候補へ戻る() throws {
		let rule = Syntax {
			Fragment(label: "value") {
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

	@Test func Fragment内部の反復が上限の回数に一致する() throws {
		let rule = Syntax {
			Fragment(label: "value") {
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

	@Test func Fragment内部の反復が下限に届かない() throws {
		let rule = Syntax {
			Fragment(label: "value") {
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

	@Test func 本文が空のFragmentの出力を比較する() throws {
		let rule = Syntax {
			Fragment(label: "empty") {
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

	@Test func 空文字列のFragmentの結果を比較する() throws {
		let rule = Syntax {
			Fragment(label: "empty", "")
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

	@Test func Fragmentが先頭で不一致になる() throws {
		let rule = Syntax {
			Fragment("a")
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

	@Test func Fragmentが文字列の途中でEOFになる() throws {
		let rule = Syntax {
			Fragment("abc")
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

	@Test func Fragmentの後に余分な入力が残る() throws {
		let rule = Syntax {
			Fragment(label: "value", "a")
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

	@Test func Fragmentで改行そのものを読む() throws {
		let rule = Syntax {
			Fragment(label: "newline", "\n")
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

	@Test func 先頭に空白があるFragmentの結果を比較する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
		}

		let source: String
		= " a"

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

	@Test func Fragmentの末尾の空白を本文の範囲へ含めない() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
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

	@Test func 隣接するFragmentを空白なしで読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Fragment(label: "B", "b")
		}

		let source: String
		= "ab"

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

	@Test func 隣接するFragmentの間の空白で失敗する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
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

	@Test func Fragmentで要素間の空白を明示的に読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Fragment(" ")
			Fragment(label: "B", "b")
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
				Tree(" ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func Fragmentの後のTokenは空白を読み飛ばす() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
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

}
