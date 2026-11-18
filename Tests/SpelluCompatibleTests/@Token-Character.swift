// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行14件、一致14件、差異0件。
// ✅ Characterのallで改行を含む文字列を読む：I=S=H 成功
// ✅ Characterのspaceで空白とタブと全角空白を読む：I=S=H 成功
// ✅ Characterのnewlineで改行を読む：I=S=H 成功
// ✅ CharacterのnotNewlineで一行の本文を読む：I=S=H 成功
// ✅ CharacterのdigitでUnicodeの十進数字を読む：I=S=H 成功
// ✅ Characterのwordで日本語を含む識別子を読む：I=S=H 成功
// ✅ Characterのgeneralで大文字カテゴリを指定する：I=S=H 成功
// ✅ CharacterのbinaryでAlphabeticプロパティを指定する：I=S=H 成功
// ✅ Characterのanyで指定した記号から選んで読む：I=S=H 成功
// ✅ Characterのrangeで小文字の範囲を指定する：I=S=H 成功
// ✅ Characterのincludeで語文字とハイフンを組み合わせる：I=S=H 成功
// ✅ Characterのexcludeで数字と空白を除外する：I=S=H 成功
// ✅ Characterの集合を反転して引用符以外を読む：I=S=H 成功
// ✅ Characterの大小文字を無視して原文を保持する：I=S=H 成功
// 一覧ここまで

import Spellu


// Characterの文字クラスを使う例。各種類の代表例を3エンジンで比較する。
// 空白や改行も字句に含めて読むため、自動読み捨てはspaces: []で無効にする。
// 期待値はasis/compactの実出力から採取する。
@Suite struct TokenCharacterTests {

	@Test func Characterのallで改行を含む文字列を読む() throws {
		let rule = Syntax {
			Token(label: "text") {
				Character.all.repeat(1...)
			}
		}

		let source: String
		= "日🙂\nA"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "text", "日🙂\nA")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "text", "日🙂\nA")
			},
		)
	}

	@Test func Characterのspaceで空白とタブと全角空白を読む() throws {
		let rule = Syntax {
			Token(label: "spacing") {
				Character.space.repeat(1...)
			}
		}

		let source: String
		= " \t\u{3000}"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "spacing", " \t\u{3000}")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "spacing", " \t\u{3000}")
			},
		)
	}

	@Test func Characterのnewlineで改行を読む() throws {
		let rule = Syntax {
			Token(label: "lineBreak") {
				Character.newline.repeat(1...)
			}
		}

		let source: String
		= "\r\n"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "lineBreak", "\r\n")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "lineBreak", "\r\n")
			},
		)
	}

	@Test func CharacterのnotNewlineで一行の本文を読む() throws {
		let rule = Syntax {
			Token(label: "line") {
				Character.notNewline.repeat(1...)
			}
		}

		let source: String
		= "一行の本文。"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "line", "一行の本文。")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "line", "一行の本文。")
			},
		)
	}

	@Test func CharacterのdigitでUnicodeの十進数字を読む() throws {
		let rule = Syntax {
			Token(label: "number") {
				Character.digit.repeat(1...)
			}
		}

		let source: String
		= "12９٠"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "number", "12９٠")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "number", "12９٠")
			},
		)
	}

	@Test func Characterのwordで日本語を含む識別子を読む() throws {
		let rule = Syntax {
			Token(label: "identifier") {
				Character.word.repeat(1...)
			}
		}

		let source: String
		= "name_日本１２"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "identifier", "name_日本１２")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "identifier", "name_日本１２")
			},
		)
	}

	@Test func Characterのgeneralで大文字カテゴリを指定する() throws {
		let rule = Syntax {
			Token(label: "uppercase") {
				Character.general(.uppercaseLetter).repeat(1...)
			}
		}

		let source: String
		= "ABCΩ"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "uppercase", "ABCΩ")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "uppercase", "ABCΩ")
			},
		)
	}

	@Test func CharacterのbinaryでAlphabeticプロパティを指定する() throws {
		let rule = Syntax {
			Token(label: "letters") {
				Character.binary(.alphabetic).repeat(1...)
			}
		}

		let source: String
		= "Hello日本"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "letters", "Hello日本")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "letters", "Hello日本")
			},
		)
	}

	@Test func Characterのanyで指定した記号から選んで読む() throws {
		let rule = Syntax {
			Token(label: "symbols") {
				Character.any("○△□").repeat(1...)
			}
		}

		let source: String
		= "□○△"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "symbols", "□○△")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "symbols", "□○△")
			},
		)
	}

	@Test func Characterのrangeで小文字の範囲を指定する() throws {
		let rule = Syntax {
			Token(label: "lowercase") {
				Character.range("a"..."z").repeat(1...)
			}
		}

		let source: String
		= "swift"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "lowercase", "swift")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "lowercase", "swift")
			},
		)
	}

	@Test func Characterのincludeで語文字とハイフンを組み合わせる() throws {
		let rule = Syntax {
			Token(label: "name") {
				Character.include(
					Character.word,
					Character.any("-"),
				).repeat(1...)
			}
		}

		let source: String
		= "user-name_1"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "name", "user-name_1")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "name", "user-name_1")
			},
		)
	}

	@Test func Characterのexcludeで数字と空白を除外する() throws {
		let rule = Syntax {
			Token(label: "body") {
				Character.exclude(
					Character.digit,
					Character.space,
				).repeat(1...)
			}
		}

		let source: String
		= "名前🙂!"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "body", "名前🙂!")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "body", "名前🙂!")
			},
		)
	}

	@Test func Characterの集合を反転して引用符以外を読む() throws {
		let rule = Syntax {
			Token(label: "contents") {
				Character.any("\"").inverted.repeat(1...)
			}
		}

		let source: String
		= "quoted text"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "contents", "quoted text")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "contents", "quoted text")
			},
		)
	}

	@Test func Characterの大小文字を無視して原文を保持する() throws {
		let rule = Syntax {
			Token(label: "word") {
				Character.range("a"..."z").ignoresCase().repeat(1...)
			}
		}

		let source: String
		= "Swift"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: [],
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "word", "Swift")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "word", "Swift")
			},
		)
	}

}
