// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行25件、一致25件、差異0件。
// ✅ 一候補のChoiceOfが一致する：I=S=H 成功
// ✅ ChoiceOfの先頭候補が一致する：I=S=H 成功
// ✅ ChoiceOfの後続候補が一致する：I=S=H 成功
// ✅ ChoiceOfの三つ目の候補が一致する：I=S=H 成功
// ✅ ラベルのないChoiceOfの候補が一致する：I=S=H 成功
// ✅ 同じ入力に一致するChoiceOfの先の候補を選ぶ：I=S=H 成功
// ✅ 同じ入力のSequence候補をChoiceOfで選ぶ：I=S=H 成功
// ✅ 短い候補が先のChoiceOfを全体一致で比較する：I=S=H 成功
// ✅ 長い候補が先のChoiceOfを全体一致で比較する：I=S=H 成功
// ✅ 短い候補が先のChoiceOfと後続の一致を比較する：I=S=H 成功
// ✅ ChoiceOfの外側の失敗で候補を選び直すか比較する：I=S=H 成功
// ✅ ChoiceOfの候補が部分一致で失敗した場合を比較する：I=S=H 成功
// ✅ ChoiceOfの候補をラベルのないSequenceでまとめる：I=S=H 成功
// ✅ ChoiceOfの候補をラベル付きSequenceでまとめる：I=S=H 成功
// ✅ ChoiceOf全体をラベル付きSequenceで包む：I=S=H 成功
// ✅ ChoiceOfを入れ子にする：I=S=H 成功
// ✅ 反復ごとにChoiceOfの候補を選ぶ：I=S=H 成功
// ✅ ChoiceOfを含むOptionalを省略する：I=S=H 成功
// ✅ 空のSequence候補を持つChoiceOfを比較する：I=S=H 成功
// ✅ 空のChoiceOfを比較する：I=S=H 不一致
// ✅ ChoiceOfのToken候補で空白を読み飛ばす：I=S=H 成功
// ✅ ChoiceOfでUnicodeの候補を選ぶ：I=S=H 成功
// ✅ ChoiceOfの全候補が先頭で失敗する：I=S=H 不一致
// ✅ ChoiceOfの同じ最遠位置の期待値を比較する：I=S=H 不一致
// ✅ ChoiceOfの最も先で失敗した候補の期待値を返す：I=S=H 不一致
// 一覧ここまで

import Spellu


// ChoiceOfのCompatible Tests。
// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
@Suite struct SyntaxChoiceOfTests {

	@Test func 一候補のChoiceOfが一致する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "A", "a")
			}
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

	@Test func ChoiceOfの先頭候補が一致する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
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

	@Test func ChoiceOfの後続候補が一致する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
		}

		let source: String
		= "b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "B", "b")
			},
		)
	}

	@Test func ChoiceOfの三つ目の候補が一致する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
				Fragment(label: "C", "c")
			}
		}

		let source: String
		= "c"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "C", "c")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "C", "c")
			},
		)
	}

	@Test func ラベルのないChoiceOfの候補が一致する() throws {
		let rule = Syntax {
			ChoiceOf {
				"a"
				"b"
			}
		}

		let source: String
		= "b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("b")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 同じ入力に一致するChoiceOfの先の候補を選ぶ() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "first", "a")
				Fragment(label: "second", "a")
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "first", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "first", "a")
			},
		)
	}

	@Test func 同じ入力のSequence候補をChoiceOfで選ぶ() throws {
		let rule = Syntax {
			ChoiceOf {
				Sequence(label: "first") {
					"a"
					"b"
				}
				Sequence(label: "second") {
					"a"
					"b"
				}
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
				Tree(label: "first", "ab") {
					Tree("a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "first", "ab")
			},
		)
	}

	@Test func 短い候補が先のChoiceOfを全体一致で比較する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "short", "a")
				Fragment(label: "long", "ab")
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
				Tree(label: "long", "ab") {
					Tree("a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "long", "ab")
			},
		)
	}

	@Test func 長い候補が先のChoiceOfを全体一致で比較する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "long", "ab")
				Fragment(label: "short", "a")
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
				Tree(label: "long", "ab"){
					Tree("a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "long", "ab")
			},
		)
	}

	@Test func 短い候補が先のChoiceOfと後続の一致を比較する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "short", "a")
				Fragment(label: "long", "ab")
			}
			Fragment(label: "tail", "b")
		}

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "short", "a")
				Tree(label: "tail", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "short", "a")
				Tree(label: "tail", "b")
			},
		)
	}

	@Test func ChoiceOfの外側の失敗で候補を選び直すか比較する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "long", "ab")
				Fragment(label: "short", "a")
			}
			Fragment(label: "tail", "b")
		}

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "short", "a")
				Tree(label: "tail", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "short", "a")
				Tree(label: "tail", "b")
			},
		)

	}

	@Test func ChoiceOfの候補が部分一致で失敗した場合を比較する() throws {
		let rule = Syntax {
			ChoiceOf {
				Sequence {
					Fragment("ab")
					Fragment("x")
				}
				Fragment(label: "fallback", "a")
			}
			Fragment(label: "tail", "bc")
		}

		let source: String
		= "abc"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "fallback", "a")
				Tree(label: "tail", "bc") {
					Tree("b")
					Tree("c")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "fallback", "a")
				Tree(label: "tail", "bc")
			},
		)
	}

	@Test func ChoiceOfの候補をラベルのないSequenceでまとめる() throws {
		let rule = Syntax {
			ChoiceOf {
				Sequence {
					Fragment(label: "A", "a")
					Fragment("b")
				}
				Fragment(label: "C", "c")
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
				Tree(label: "#and", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
			},
		)
	}

	@Test func ChoiceOfの候補をラベル付きSequenceでまとめる() throws {
		let rule = Syntax {
			ChoiceOf {
				Sequence(label: "pair") {
					Fragment(label: "A", "a")
					Fragment("b")
				}
				Fragment(label: "C", "c")
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
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
				}
			},
		)
	}

	@Test func ChoiceOf全体をラベル付きSequenceで包む() throws {
		let rule = Syntax {
			Sequence(label: "selected") {
				ChoiceOf {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
			}
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "selected", "a") {
					Tree(label: "A", "a")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "selected", "a") {
					Tree(label: "A", "a")
				}
			},
		)
	}

	@Test func ChoiceOfを入れ子にする() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "X", "x")
				ChoiceOf {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
			}
		}

		let source: String
		= "b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "B", "b")
			},
		)
	}

	@Test func 反復ごとにChoiceOfの候補を選ぶ() throws {
		let rule = Syntax {
			Repeat(2...2) {
				ChoiceOf {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
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
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func ChoiceOfを含むOptionalを省略する() throws {
		let rule = Syntax {
			Optional {
				ChoiceOf {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
			}
		}

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source),
			compact: Tree(label: "$", source),
		)
	}

	@Test func 空のSequence候補を持つChoiceOfを比較する() throws {
		let rule = Syntax {
			ChoiceOf {
				Sequence {
				}
				Fragment(label: "A", "a")
			}
			Fragment(label: "tail", "a")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#and", "")
				Tree(label: "tail", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "tail", "a")
			},
		)
	}

	@Test func 空のChoiceOfを比較する() throws {
		let rule = Syntax {
			ChoiceOf {}
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

	@Test func ChoiceOfのToken候補で空白を読み飛ばす() throws {
		let rule = Syntax {
			ChoiceOf {
				Token(label: "A", "a")
				Token(label: "B", "b")
			}
			Token(label: "tail", "c")
		}

		let source: String
		= "b c"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "B", "b")
				Tree(label: "tail", "c")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "B", "b")
				Tree(label: "tail", "c")
			},
		)
	}

	@Test func ChoiceOfでUnicodeの候補を選ぶ() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "猫", "猫")
				Fragment(label: "犬", "犬")
			}
		}

		let source: String
		= "犬"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "犬", "犬")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "犬", "犬")
			},
		)
	}

	@Test func ChoiceOfの全候補が先頭で失敗する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
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
				expects: [.literal("a"), .literal("b")],
			),
		)
	}

	@Test func ChoiceOfの同じ最遠位置の期待値を比較する() throws {
		let rule = Syntax {
			ChoiceOf {
				Fragment(label: "A", "ab")
				Fragment(label: "B", "ac")
			}
		}

		let source: String
		= "aX"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("b"), .literal("c")],
			),
		)
	}

	@Test func ChoiceOfの最も先で失敗した候補の期待値を返す() throws {
		let rule = Syntax {
			ChoiceOf {
				Sequence {
					Fragment("ab")
					Fragment(label: "C", "c")
				}
				Fragment(label: "X", "x")
			}
		}

		let source: String
		= "ab!"

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

}
