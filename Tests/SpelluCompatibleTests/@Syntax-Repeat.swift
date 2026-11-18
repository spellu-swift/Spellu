// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行30件、一致30件、差異0件。
// ✅ Repeatを0回繰り返す：I=S=H 成功
// ✅ Repeatを1回繰り返す：I=S=H 成功
// ✅ ラベルのない要素を複数回繰り返す：I=S=H 成功
// ✅ ラベル付きの要素を複数回繰り返す：I=S=H 成功
// ✅ 複数の要素を一回分として繰り返す：I=S=H 成功
// ✅ ラベルのないSequenceを繰り返す：I=S=H 成功
// ✅ ラベル付きのSequenceを繰り返す：I=S=H 成功
// ✅ Repeat全体をラベル付きSequenceで包む：I=S=H 成功
// ✅ Repeatを入れ子にする：I=S=H 成功
// ✅ 繰り返すTokenの間の空白を読み飛ばす：I=S=H 成功
// ✅ Unicode文字を繰り返す：I=S=H 成功
// ✅ 固定回数0では本文を読まず後続へ進む：I=S=H 成功
// ✅ 最小回数1のRepeat：I=S=H 成功
// ✅ 下限のみ指定したRepeatは最小回数でも一致する：I=S=H 成功
// ✅ 固定回数のRepeat：I=S=H 成功
// ✅ 上限のみ指定したRepeat：I=S=H 成功
// ✅ 上限1のRepeat：I=S=H 成功
// ✅ 範囲を指定したRepeatが下限に一致する：I=S=H 成功
// ✅ 範囲を指定したRepeatが範囲の途中に一致する：I=S=H 成功
// ✅ 範囲を指定したRepeatが上限に一致する：I=S=H 成功
// ✅ Repeatが下限の回数に届かない：I=S=H 不一致
// ✅ Repeatの上限を超える入力が残る：I=S=H 不一致
// ✅ 最低1回必要なRepeatは空入力に一致しない：I=S=H 不一致
// ✅ Repeat内部の部分一致に失敗する：I=S=H 不一致
// ✅ reluctantは後続に一致する位置で反復を止める：I=S=H 成功
// ✅ eagerは上限まで反復してから後続へ進む：I=S=H 成功
// ✅ reluctantでも指定された最小回数を先に読む：I=S=H 成功
// ✅ eagerの後続の失敗で反復を巻き戻すか比較する：I=S=H 成功
// ✅ reluctantは後続の部分一致失敗を巻き戻す：I=S=H 成功
// ✅ eagerとreluctantで二つのRepeatへの分配を比較する：I=S=H 成功
// 一覧ここまで

import Spellu


// RepeatのCompatible Tests。
// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
// 共通の出力は1回のcompatibleTestで明示し、behaviorの差異も比較する。
@Suite struct SyntaxRepeatTests {

	@Test func Repeatを0回繰り返す() throws {
		let rule = Syntax {
			Repeat {
				"a"
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

	@Test func Repeatを1回繰り返す() throws {
		let rule = Syntax {
			Repeat {
				"a"
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
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ラベルのない要素を複数回繰り返す() throws {
		let rule = Syntax {
			Repeat {
				"a"
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
				Tree("a")
				Tree("a")
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ラベル付きの要素を複数回繰り返す() throws {
		let rule = Syntax {
			Repeat {
				Fragment(label: "A", "a")
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
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 複数の要素を一回分として繰り返す() throws {
		let rule = Syntax {
			Repeat {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
		}

		let source: String
		= "abab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func ラベルのないSequenceを繰り返す() throws {
		let rule = Syntax {
			Repeat {
				Sequence {
					Fragment(label: "A", "a")
					Fragment("b")
				}
			}
		}

		let source: String
		= "abab"

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
				Tree(label: "#and", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func ラベル付きのSequenceを繰り返す() throws {
		let rule = Syntax {
			Repeat {
				Sequence(label: "pair") {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
			}
		}

		let source: String
		= "abab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree(label: "B", "b")
				}
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree(label: "B", "b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree(label: "B", "b")
				}
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree(label: "B", "b")
				}
			},
		)
	}

	@Test func Repeat全体をラベル付きSequenceで包む() throws {
		let rule = Syntax {
			Sequence(label: "items") {
				Repeat {
					Fragment(label: "A", "a")
				}
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "items", "aa") {
					Tree(label: "A", "a")
					Tree(label: "A", "a")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "items", "aa") {
					Tree(label: "A", "a")
					Tree(label: "A", "a")
				}
			},
		)
	}

	@Test func Repeatを入れ子にする() throws {
		let rule = Syntax {
			Repeat {
				Fragment("[")
				Repeat {
					Fragment(label: "A", "a")
				}
				Fragment("]")
			}
		}

		let source: String
		= "[aa][a]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("[")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree("]")
				Tree("[")
				Tree(label: "A", "a")
				Tree("]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 繰り返すTokenの間の空白を読み飛ばす() throws {
		let rule = Syntax {
			Repeat {
				Token(label: "A", "a")
			}
		}

		let source: String
		= "a a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Unicode文字を繰り返す() throws {
		let rule = Syntax {
			Repeat {
				Fragment(label: "A", "猫")
			}
		}

		let source: String
		= "猫猫"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "猫")
				Tree(label: "A", "猫")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "猫")
				Tree(label: "A", "猫")
			},
		)
	}

	@Test func 固定回数0では本文を読まず後続へ進む() throws {
		let rule = Syntax {
			Sequence(label: "zero") {
				Repeat(0...0) {
					Fragment(label: "A", "a")
				}
			}
			Fragment(label: "B", "b")
		}

		let source: String
		= "b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "zero", "")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "zero", "")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func 最小回数1のRepeat() throws {
		let rule = Syntax {
			Repeat(1...) {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 下限のみ指定したRepeatは最小回数でも一致する() throws {
		let rule = Syntax {
			Repeat(2...) {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 固定回数のRepeat() throws {
		let rule = Syntax {
			Repeat(2...2) {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 上限のみ指定したRepeat() throws {
		let rule = Syntax {
			Repeat(...3) {
				Fragment(label: "A", "a")
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
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 上限1のRepeat() throws {
		let rule = Syntax {
			Repeat(0...1) {
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

	@Test func 範囲を指定したRepeatが下限に一致する() throws {
		let rule = Syntax {
			Repeat(1...3) {
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

	@Test func 範囲を指定したRepeatが範囲の途中に一致する() throws {
		let rule = Syntax {
			Repeat(1...3) {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "aa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 範囲を指定したRepeatが上限に一致する() throws {
		let rule = Syntax {
			Repeat(1...3) {
				Fragment(label: "A", "a")
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
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Repeatが下限の回数に届かない() throws {
		let rule = Syntax {
			Repeat(2...3) {
				Fragment(label: "A", "a")
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

	@Test func Repeatの上限を超える入力が残る() throws {
		let rule = Syntax {
			Repeat(1...3) {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "aaaa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 3,
				line: 1,
				column: 4,
				expects: [.eos],
			),
		)
	}

	@Test func 最低1回必要なRepeatは空入力に一致しない() throws {
		let rule = Syntax {
			Repeat(1...) {
				Fragment(label: "A", "a")
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
				expects: [.literal("a")],
			),
		)
	}

	@Test func Repeat内部の部分一致に失敗する() throws {
		let rule = Syntax {
			Repeat {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
		}

		let source: String
		= "aba"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 3,
				line: 1,
				column: 4,
				expects: [.literal("b")],
			),
		)
	}

	@Test func reluctantは後続に一致する位置で反復を止める() throws {
		let rule = Syntax {
			Repeat(0...2, behavior: .reluctant) {
				Fragment(label: "A", "a")
			}
			Fragment(label: "separator", "a")
			Repeat {
				Fragment(label: "B", "a")
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
				Tree(label: "separator", "a")
				Tree(label: "B", "a")
				Tree(label: "B", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "separator", "a")
				Tree(label: "B", "a")
				Tree(label: "B", "a")
			},
		)
	}

	@Test func eagerは上限まで反復してから後続へ進む() throws {
		let rule = Syntax {
			Repeat(0...2, behavior: .eager) {
				Fragment(label: "A", "a")
			}
			Fragment(label: "separator", "a")
			Repeat {
				Fragment(label: "B", "a")
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
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "separator", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "separator", "a")
			},
		)
	}

	@Test func reluctantでも指定された最小回数を先に読む() throws {
		let rule = Syntax {
			Repeat(1...3, behavior: .reluctant) {
				Fragment(label: "A", "a")
			}
			Fragment(label: "tail", "a")
		}

		let source: String
		= "aa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "tail", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "tail", "a")
			},
		)
	}

	@Test func eagerの後続の失敗で反復を巻き戻すか比較する() throws {
		let rule = Syntax {
			Repeat(behavior: .eager) {
				Fragment(label: "A", "a")
			}
			Fragment(label: "tail", "a")
		}

		let source: String
		= "aa"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "tail", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "tail", "a")
			},
		)

	}

	@Test func reluctantは後続の部分一致失敗を巻き戻す() throws {
		let rule = Syntax {
			Repeat(0...2, behavior: .reluctant) {
				Fragment(label: "A", "a")
			}
			Fragment(label: "tail", "ab")
		}

		let source: String
		= "aaab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "tail", "ab") {
					Tree("a")
					Tree("b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "tail", "ab")
			},
		)
	}

	@Test func eagerとreluctantで二つのRepeatへの分配を比較する() throws {
		for behavior: SyntaxRepetitionBehavior in [.eager, .reluctant] {
			let rule = Syntax {
				Sequence(label: "first") {
					Repeat(behavior: behavior) { Fragment("a") }
				}
				Sequence(label: "second") {
					Repeat { Fragment("a") }
				}
			}
			let eager: Bool = behavior == .eager
			let first: String = eager ? "aa" : ""
			let second: String = eager ? "" : "aa"

			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				spaces: [],
				source: "aa",
				match: "aa",
				asis: Tree(label: "$", "aa") {
					Tree(label: "first", first) {
						eager ? [Tree("a"), Tree("a")] : []
					}
					Tree(label: "second", second) {
						eager ? [] : [Tree("a"), Tree("a")]
					}
				},
				compact: Tree(label: "$", "aa") {
					Tree(label: "first", first)
					Tree(label: "second", second)
				},
			)
		}
	}

}
