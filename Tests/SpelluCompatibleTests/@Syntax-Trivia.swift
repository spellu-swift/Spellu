// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行35件、一致35件、差異0件。
// ✅ Triviaだけで一つの空白を読む：I=S=H 成功
// ✅ Triviaだけで連続する空白を読む：I=S=H 成功
// ✅ Triviaの空入力での結果を比較する：I=S=H 不一致
// ✅ Triviaに一致しない文字が先頭にある：I=S=H 不一致
// ✅ Fragmentの間のTriviaを読む：I=S=H 成功
// ✅ Fragmentの間の連続するTriviaを読む：I=S=H 成功
// ✅ Fragmentの間にTriviaがない場合を比較する：I=S=H 不一致
// ✅ 先頭のTriviaを明示的に読む：I=S=H 成功
// ✅ 末尾のTriviaを明示的に読む：I=S=H 成功
// ✅ 前後のTriviaを明示的に読む：I=S=H 成功
// ✅ Tokenの後のTriviaを明示的に読む：I=S=H 成功
// ✅ Triviaの後にTokenを置く：I=S=H 成功
// ✅ Tokenの自動Triviaと明示的Triviaを組み合わせる：I=S=H 成功
// ✅ Triviaの定義が空の場合を比較する：I=S=H 空一致エラー
// ✅ 空白だけの定義で改行を読む場合を比較する：I=S=H 不一致
// ✅ 改行をTriviaとして読む：I=S=H 成功
// ✅ 空白と改行を交互にTriviaとして読む：I=S=H 成功
// ✅ Unicodeの空白をTriviaとして読む：I=S=H 成功
// ✅ Unicodeの数字を文字クラスのTriviaとして読む：I=S=H 成功
// ✅ Unicodeの語文字をTriviaとして読む：I=S=H 成功
// ✅ 文字列をTriviaとして読む：I=S=H 成功
// ✅ 複数の文字列をTriviaとして連続して読む：I=S=H 成功
// ✅ TokenIRのパターンをTriviaとして読む：I=S=H 成功
// ✅ TokenIRのパターンをTriviaとして連続して読む：I=S=H 成功
// ✅ TriviaのTokenIRで大小文字を無視する：I=S=H 成功
// ✅ TriviaのTokenIR内部の部分一致失敗を比較する：I=S=H 不一致
// ✅ 異なる種類のTriviaを交互に読む：I=S=H 成功
// ✅ 本文の先頭文字もTriviaに含まれる場合を比較する：I=S=H 不一致
// ✅ Fragmentで先頭を読んでから語文字のTriviaへ進む：I=S=H 成功
// ✅ Triviaをラベル付きSequence内に置く：I=S=H 成功
// ✅ Optional内部のTriviaが一致する：I=S=H 成功
// ✅ Optional内部のTriviaを省略する：I=S=H 成功
// ✅ Triviaを含む本文を固定回数繰り返す：I=S=H 成功
// ✅ Triviaの不一致後にChoiceOfの別候補へ進む：I=S=H 成功
// ✅ 既定のTrivia定義で空白を明示的に読む：I=S=H 成功
// 一覧ここまで

import Spellu


// TriviaのCompatible Tests。
// SpacePatternの字句パターンと、明示的なTriviaの木・エラーを比較する。
// 期待値は3エンジンのasis/compactの実出力から採取する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct SyntaxTriviaTests {

	@Test func Triviaだけで一つの空白を読む() throws {
		let rule = Syntax {
			Trivia
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= " "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#spaces", " ")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Triviaだけで連続する空白を読む() throws {
		let rule = Syntax {
			Trivia
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "   "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#spaces", "   ")
			},
			compact: Tree(label: "$", source),
		)

	}

	@Test func Triviaの空入力での結果を比較する() throws {
		let rule = Syntax {
			Trivia
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.special("TRIVIA")],
			),
		)
	}

	@Test func Triviaに一致しない文字が先頭にある() throws {
		let rule = Syntax {
			Trivia
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "x"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.special("TRIVIA")],
			),
		)
	}

	@Test func Fragmentの間のTriviaを読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", " ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func Fragmentの間の連続するTriviaを読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a   b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "   ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func Fragmentの間にTriviaがない場合を比較する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.special("TRIVIA")],
			),
		)
	}

	@Test func 先頭のTriviaを明示的に読む() throws {
		let rule = Syntax {
			Trivia
			Fragment(label: "A", "a")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= " a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#spaces", " ")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
			},
		)

	}

	@Test func 末尾のTriviaを明示的に読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", " ")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
			},
		)

	}

	@Test func 前後のTriviaを明示的に読む() throws {
		let rule = Syntax {
			Trivia
			Fragment(label: "A", "a")
			Trivia
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= " a "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#spaces", " ")
				Tree(label: "A", "a")
				Tree(label: "#spaces", " ")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
			},
		)

	}

	@Test func Tokenの後のTriviaを明示的に読む() throws {
		let rule = Syntax {
			Token(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", " ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func Triviaの後にTokenを置く() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Token(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", " ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func Tokenの自動Triviaと明示的Triviaを組み合わせる() throws {
		let rule = Syntax {
			Token(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= " a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: "a b",
			asis: Tree(label: "$", "a b") {
				Tree(label: "A", "a")
				Tree(label: "#spaces", " ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", "a b") {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func Triviaの定義が空の場合を比較する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= []

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			error: .emptyMatch(rule: "Trivia"),
		)
	}

	@Test func 空白だけの定義で改行を読む場合を比較する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a\nb"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.special("TRIVIA")],
			),
		)
	}

	@Test func 改行をTriviaとして読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.newline,
		]

		let source: String
		= "a\nb"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "\n")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func 空白と改行を交互にTriviaとして読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
			.newline,
		]

		let source: String
		= "a \r\n\tb"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", " \r\n\t")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func Unicodeの空白をTriviaとして読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a\u{3000}\u{a0}b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "\u{3000}\u{a0}")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func Unicodeの数字を文字クラスのTriviaとして読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.character(.digit),
		]

		let source: String
		= "a1９٠b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "1９٠")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func Unicodeの語文字をTriviaとして読む() throws {
		let rule = Syntax {
			Fragment(":")
			Trivia
			Fragment(":")
		}

		let spaces: [SpacePattern]
		= [
			.character(.word),
		]

		let source: String
		= ":日本_1:"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(":")
				Tree(label: "#spaces", "日本_1")
				Tree(":")
			},
			compact: Tree(label: "$", source),
		)

	}

	@Test func 文字列をTriviaとして読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.string("/*x*/"),
		]

		let source: String
		= "a/*x*/b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "/*x*/")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func 複数の文字列をTriviaとして連続して読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.string("/*x*/"),
		]

		let source: String
		= "a/*x*//*x*/b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "/*x*//*x*/")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func TokenIRのパターンをTriviaとして読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.token(Sequence {
				"/*"
				Character.word.repeat(1...)
				"*/"
			}),
		]

		let source: String
		= "a/*x*/b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "/*x*/")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func TokenIRのパターンをTriviaとして連続して読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.token(Sequence {
				"/*"
				Character.word.repeat(1...)
				"*/"
			}),
		]

		let source: String
		= "a/*x*//*y*/b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "/*x*//*y*/")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func TriviaのTokenIRで大小文字を無視する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.token("x".ignoresCase()),
		]

		let source: String
		= "aXb"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", "X")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func TriviaのTokenIR内部の部分一致失敗を比較する() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.token(Sequence {
				"/*"
				Character.word.repeat(1...)
				"*/"
			}),
		]

		let source: String
		= "a/*xb"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 5,
				line: 1,
				column: 6,
				expects: [.special("TRIVIA")],
			),
		)
	}

	@Test func 異なる種類のTriviaを交互に読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
			Fragment(label: "B", "b")
		}

		let spaces: [SpacePattern]
		= [
			.space,
			.string("#"),
			.character(.digit),
		]

		let source: String
		= "a #12 b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "#spaces", " #12 ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

	@Test func 本文の先頭文字もTriviaに含まれる場合を比較する() throws {
		let rule = Syntax {
			"a"
			Trivia
			Fragment(":")
		}

		let spaces: [SpacePattern]
		= [
			.space,
			.character(.word),
		]

		let source: String
		= " a  b :"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 6,
				line: 1,
				column: 7,
				expects: [.literal("a")],
			),
		)
	}

	@Test func Fragmentで先頭を読んでから語文字のTriviaへ進む() throws {
		let rule = Syntax {
			Fragment(" a")
			Trivia
			Fragment(":")
		}

		let spaces: [SpacePattern]
		= [
			.space,
			.character(.word),
		]

		let source: String
		= " a  b :"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(" a")
				Tree(label: "#spaces", "  b ")
				Tree(":")
			},
			compact: Tree(label: "$", source),
		)

	}

	@Test func Triviaをラベル付きSequence内に置く() throws {
		let rule = Syntax {
			Sequence(label: "pair") {
				Fragment(label: "A", "a")
				Trivia
				Fragment(label: "B", "b")
			}
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "pair", "a b") {
					Tree(label: "A", "a")
					Tree(label: "#spaces", " ")
					Tree(label: "B", "b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", "a b") {
					Tree(label: "A", "a")
					Tree(label: "B", "b")
				}
			},
		)

	}

	@Test func Optional内部のTriviaが一致する() throws {
		let rule = Syntax {
			Optional {
				Trivia
			}
			Fragment("!")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= " !"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#spaces", " ")
				Tree("!")
			},
			compact: Tree(label: "$", source),
		)

	}

	@Test func Optional内部のTriviaを省略する() throws {
		let rule = Syntax {
			Optional {
				Trivia
			}
			Fragment("!")
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "!"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("!")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Triviaを含む本文を固定回数繰り返す() throws {
		let rule = Syntax {
			Repeat(2...2) {
				Fragment(label: "item", "a")
				Trivia
			}
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "a a "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "item", "a")
				Tree(label: "#spaces", " ")
				Tree(label: "item", "a")
				Tree(label: "#spaces", " ")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "item", "a")
				Tree(label: "item", "a")
			},
		)

	}

	@Test func Triviaの不一致後にChoiceOfの別候補へ進む() throws {
		let rule = Syntax {
			ChoiceOf {
				Sequence {
					Fragment(label: "A", "a")
					Trivia
					Fragment(label: "B", "b")
				}
				Fragment(label: "fallback", "ab")
			}
		}

		let spaces: [SpacePattern]
		= [
			.space,
		]

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "fallback", "ab") {
					Tree("a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "fallback", "ab")
			},
		)
	}

	@Test func 既定のTrivia定義で空白を明示的に読む() throws {
		let rule = Syntax {
			Fragment(label: "A", "a")
			Trivia
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
				Tree(label: "#spaces", " ")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)

	}

}
