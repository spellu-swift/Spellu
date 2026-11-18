// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行44件、一致44件、差異0件。
// ✅ Repeatを0回繰り返す：I=S=H 成功
// ✅ Repeatを1回繰り返す：I=S=H 成功
// ✅ Repeatを複数回繰り返す：I=S=H 成功
// ✅ 最低1回必要なRepeatは空入力に一致しない：I=S=H 不一致
// ✅ 最低1回必要なRepeatが1回に一致する：I=S=H 成功
// ✅ 範囲指定のRepeatが下限に一致する：I=S=H 成功
// ✅ 範囲指定のRepeatが範囲の途中に一致する：I=S=H 成功
// ✅ 範囲指定のRepeatが上限に一致する：I=S=H 成功
// ✅ Repeatが下限の回数に届かない：I=S=H 不一致
// ✅ Repeatの上限を超える入力が残る：I=S=H 不一致
// ✅ 下限のみ指定したRepeatが最小回数に一致する：I=S=H 成功
// ✅ 上限を含む範囲のRepeatが上限に一致する：I=S=H 成功
// ✅ 上限を含まない範囲のRepeatが最大回数に一致する：I=S=H 成功
// ✅ 半開区間のRepeatが最大回数に一致する：I=S=H 成功
// ✅ 固定回数0のRepeatが空入力に一致する：I=S=H 成功
// ✅ 固定回数のRepeatが一致する：I=S=H 成功
// ✅ 固定回数0のRepeatは本文を読まず後続へ進む：I=S=H 成功
// ✅ 固定回数でも内部のChoiceOfを後続から選び直す：I=S=H 成功
// ✅ Repeatの複数要素を一回分として繰り返す：I=S=H 成功
// ✅ Repeat内部のSequenceを繰り返す：I=S=H 成功
// ✅ Repeatを入れ子にする：I=S=H 成功
// ✅ 空の本文のRepeatから後続へ進む：I=S=H 成功
// ✅ Repeat内部の空リテラルの結果を比較する：I=S=H 成功
// ✅ Repeat内部の空のChoiceOfの結果を比較する：I=S=H 成功
// ✅ 空成功するOptionalのRepeatから後続へ進む：I=S=H 成功
// ✅ eagerは後続のために反復回数を減らす：I=S=H 成功
// ✅ eagerの局所的な選択で字句の後に入力が残る：I=S=H 不一致
// ✅ eagerは最後の終了区切りまで読む：I=S=H 成功
// ✅ 最後の未完成反復を巻き戻して後続へ進む：I=S=H 成功
// ✅ Repeatの必須回数内の部分一致に失敗する：I=S=H 不一致
// ✅ RepeatでUnicodeの文字列を繰り返す：I=S=H 成功
// ✅ Repeatの大小文字指定とUnicodeの巻き戻しを比較する：I=S=H 成功
// ✅ Repeat内部の要素間の空白を読み飛ばさない：I=S=H 不一致
// ✅ Repeat内部の空白を明示的に読む：I=S=H 成功
// ✅ Repeatを含むTokenにラベルを付ける：I=S=H 成功
// ✅ Repeatを含む一時ラベル付きTokenのcompact出力を比較する：I=S=H 成功
// ✅ reluctantは直後の後続が一致した時点で反復を止める：I=S=H 成功
// ✅ reluctantでも指定された最小回数を先に読む：I=S=H 成功
// ✅ reluctantは後続が成立するまで反復回数を増やす：I=S=H 成功
// ✅ reluctantは最初の終了区切りまで読む：I=S=H 成功
// ✅ reluctantは固定回数でも内部のChoiceOfを選び直す：I=S=H 成功
// ✅ reluctantの上限までに後続が見つからなければ不一致になる：I=S=H 不一致
// ✅ possessiveは後続のために反復回数を減らさない：I=S=H 不一致
// ✅ possessiveの反復と後続が一致する：I=S=H 成功
// 一覧ここまで

import Spellu


// 字句ルールのRepeatのCompatible Tests。
// TokenのBuilder内に置き、4構成のasis/compactの実出力を比較する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct TokenRepeatTests {

	@Test func Repeatを0回繰り返す() throws {
		let rule = Syntax {
			Token {
				Repeat(0...) {
					"a"
				}
			}
		}

		let source: String
		= ""

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatを1回繰り返す() throws {
		let rule = Syntax {
			Token {
				Repeat(0...) {
					"a"
				}
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatを複数回繰り返す() throws {
		let rule = Syntax {
			Token {
				Repeat(0...) {
					"a"
				}
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 最低1回必要なRepeatは空入力に一致しない() throws {
		let rule = Syntax {
			Token {
				Repeat(1...) {
					"a"
				}
			}
		}

		let source: String
		= ""

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
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

	@Test func 最低1回必要なRepeatが1回に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(1...) {
					"a"
				}
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 範囲指定のRepeatが下限に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(2...4) {
					"a"
				}
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 範囲指定のRepeatが範囲の途中に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(2...4) {
					"a"
				}
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 範囲指定のRepeatが上限に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(2...4) {
					"a"
				}
			}
		}

		let source: String
		= "aaaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatが下限の回数に届かない() throws {
		let rule = Syntax {
			Token {
				Repeat(2...4) {
					"a"
				}
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
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

	@Test func Repeatの上限を超える入力が残る() throws {
		let rule = Syntax {
			Token {
				Repeat(2...4) {
					"a"
				}
			}
		}

		let source: String
		= "aaaaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 4,
				line: 1,
				column: 5,
				expects: [.eos],
			),
		)
	}

	@Test func 下限のみ指定したRepeatが最小回数に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(2...) {
					"a"
				}
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 上限を含む範囲のRepeatが上限に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(...2) {
					"a"
				}
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 上限を含まない範囲のRepeatが最大回数に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(..<3) {
					"a"
				}
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 半開区間のRepeatが最大回数に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(1..<3) {
					"a"
				}
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 固定回数0のRepeatが空入力に一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(0...0) {
					"a"
				}
			}
		}

		let source: String
		= ""

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 固定回数のRepeatが一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(2...2) {
					"a"
				}
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 固定回数0のRepeatは本文を読まず後続へ進む() throws {
		let rule = Syntax {
			Token {
				Repeat(0...0) {
					"x"
				}
				"a"
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 固定回数でも内部のChoiceOfを後続から選び直す() throws {
		let rule = Syntax {
			Token {
				Repeat(2...2) {
					ChoiceOf {
						"aa"
						"a"
					}
				}
				"a"
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatの複数要素を一回分として繰り返す() throws {
		let rule = Syntax {
			Token {
				Repeat(1...) {
					"a"
					"b"
				}
			}
		}

		let source: String
		= "ababab"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("ababab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeat内部のSequenceを繰り返す() throws {
		let rule = Syntax {
			Token {
				Repeat(1...) {
					Sequence {
						"a"
						"b"
					}
				}
			}
		}

		let source: String
		= "abab"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("abab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatを入れ子にする() throws {
		let rule = Syntax {
			Token {
				Repeat(2...2) {
					Repeat(2...2) {
						"a"
					}
				}
			}
		}

		let source: String
		= "aaaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 空の本文のRepeatから後続へ進む() throws {
		let rule = Syntax {
			Token {
				Repeat(2...3) {
				}
				"a"
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeat内部の空リテラルの結果を比較する() throws {
		let rule = Syntax {
			Token {
				Repeat(0...) {
					""
				}
				"a"
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeat内部の空のChoiceOfの結果を比較する() throws {
		let rule = Syntax {
			Token {
				Repeat(0...) {
					ChoiceOf {
					}
				}
				"b"
			}
		}

		let source: String
		= "b"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("b")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 空成功するOptionalのRepeatから後続へ進む() throws {
		let rule = Syntax {
			Token {
				Repeat(0...) {
					Optional {
						"a"
					}
				}
				"b"
			}
		}

		let source: String
		= "ab"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("ab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func eagerは後続のために反復回数を減らす() throws {
		let rule = Syntax {
			Token {
				Repeat(0..., behavior: .eager) {
					"a"
				}
				"a"
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func eagerの局所的な選択で字句の後に入力が残る() throws {
		let rule = Syntax {
			Token {
				Repeat(0..., behavior: .eager) {
					"a"
				}
				Repeat(0..., behavior: .eager) {
					"ab"
				}
			}
		}

		let source: String
		= "aab"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.eos],
			),
		)
	}

	@Test func eagerは最後の終了区切りまで読む() throws {
		let rule = Syntax {
			Token(label: "body") {
				"<"
				Repeat(0..., behavior: .eager) {
					Character.all
				}
				">"
			}
		}

		let source: String
		= "<x><y>"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "body", "<x><y>")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "body", "<x><y>")
			},
		)
	}

	@Test func 最後の未完成反復を巻き戻して後続へ進む() throws {
		let rule = Syntax {
			Token {
				Repeat(1...) {
					"_"
					"1"
				}
				"_"
			}
		}

		let source: String
		= "_1_"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("_1_")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatの必須回数内の部分一致に失敗する() throws {
		let rule = Syntax {
			Token {
				Repeat(2...) {
					"_"
					"1"
				}
			}
		}

		let source: String
		= "_1_"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 3,
				line: 1,
				column: 4,
				expects: [.literal("1")],
			),
		)
	}

	@Test func RepeatでUnicodeの文字列を繰り返す() throws {
		let rule = Syntax {
			Token {
				Repeat(2...3) {
					"日本"
				}
			}
		}

		let source: String
		= "日本日本"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("日本日本")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatの大小文字指定とUnicodeの巻き戻しを比較する() throws {
		let rule = Syntax {
			Token {
				Repeat(0...) {
					"kσ"
				}.ignoresCase()
				"kς!"
			}
		}

		let source: String
		= "KΣkς!"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("KΣkς!")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeat内部の要素間の空白を読み飛ばさない() throws {
		let rule = Syntax {
			Token {
				Repeat(2...2) {
					"a"
				}
			}
		}

		let source: String
		= "a a"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
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

	@Test func Repeat内部の空白を明示的に読む() throws {
		let rule = Syntax {
			Token {
				Repeat(2...2) {
					"a"
					" "
				}
			}
		}

		let source: String
		= "a a "

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a a ")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Repeatを含むTokenにラベルを付ける() throws {
		let rule = Syntax {
			Token(label: "value") {
				Repeat(1...) {
					"a"
				}
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
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

	@Test func Repeatを含む一時ラベル付きTokenのcompact出力を比較する() throws {
		let rule = Syntax {
			Token(label: "#value") {
				Repeat(1...) {
					"a"
				}
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#value", "aaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func reluctantは直後の後続が一致した時点で反復を止める() throws {
		let rule = Syntax {
			Token(label: "body") {
				Repeat(0..., behavior: .reluctant) {
					"a"
				}
				"a"
			}
			Fragment(label: "tail", "aa")
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "body", "a")
				Tree(label: "tail", "aa")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "body", "a")
				Tree(label: "tail", "aa")
			},
		)
	}

	@Test func reluctantでも指定された最小回数を先に読む() throws {
		let rule = Syntax {
			Token {
				Repeat(2..., behavior: .reluctant) {
					"a"
				}
				"a"
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func reluctantは後続が成立するまで反復回数を増やす() throws {
		let rule = Syntax {
			Token {
				Repeat(0..., behavior: .reluctant) {
					"a"
				}
				"b"
			}
		}

		let source: String
		= "aaab"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func reluctantは最初の終了区切りまで読む() throws {
		let rule = Syntax {
			Token(label: "body") {
				"<"
				Repeat(0..., behavior: .reluctant) {
					Character.all
				}
				">"
			}
			Fragment(label: "tail", "<y>")
		}

		let source: String
		= "<x><y>"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "body", "<x>")
				Tree(label: "tail", "<y>")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "body", "<x>")
				Tree(label: "tail", "<y>")
			},
		)
	}


	@Test func reluctantは固定回数でも内部のChoiceOfを選び直す() throws {
		let rule = Syntax {
			Token {
				Repeat(2...2, behavior: .reluctant) {
					ChoiceOf {
						"aa"
						"a"
					}
				}
				"a"
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaa")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func reluctantの上限までに後続が見つからなければ不一致になる() throws {
		let rule = Syntax {
			Token {
				Repeat(0...2, behavior: .reluctant) {
					"a"
				}
				"b"
			}
		}

		let source: String
		= "aaab"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("b")],
			),
		)
	}

	@Test func possessiveは後続のために反復回数を減らさない() throws {
		let rule = Syntax {
			Token {
				Repeat(0..., behavior: .possessive) {
					"a"
				}
				"a"
			}
		}

		let source: String
		= "aaa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 3,
				line: 1,
				column: 4,
				expects: [.literal("a")],
			),
		)
	}

	@Test func possessiveの反復と後続が一致する() throws {
		let rule = Syntax {
			Token {
				Repeat(1..., behavior: .possessive) {
					"a"
				}
				"b"
			}
		}

		let source: String
		= "aaab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("aaab")
			},
			compact: Tree(label: "$", source),
		)
	}

}
