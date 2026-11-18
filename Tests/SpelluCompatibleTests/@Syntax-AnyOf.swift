// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行28件、一致28件、差異0件。
// ✅ 一候補のAnyOfが一致する：I=S=H 成功
// ✅ AnyOfの先頭候補だけが一致する：I=S=H 成功
// ✅ AnyOfの後続候補だけが一致する：I=S=H 成功
// ✅ ラベルのないAnyOfの候補が一致する：I=S=H 成功
// ✅ AnyOfで後に書いた高順位の候補を選ぶ：I=S=H 成功
// ✅ AnyOfで先に書いた高順位の候補を選ぶ：I=S=H 成功
// ✅ AnyOfの通常候補よりmiddleの候補を優先する：I=S=H 成功
// ✅ AnyOfの高順位候補が部分一致で失敗した場合を比較する：I=S=H 成功
// ✅ 同順位のAnyOfで一候補だけが成功した場合を比較する：I=S=H 成功
// ✅ AnyOfのBranchを複数の要素で構成する：I=S=H 成功
// ✅ AnyOfの候補をラベルのないSequenceでまとめる：I=S=H 成功
// ✅ AnyOfの候補をラベル付きSequenceでまとめる：I=S=H 成功
// ✅ AnyOf全体をラベル付きSequenceで包む：I=S=H 成功
// ✅ 空のBranchを高順位で選ぶAnyOfを比較する：I=S=H 成功
// ✅ 空のAnyOfを比較する：I=S=H 不一致
// ✅ AnyOfの同順位の重複成功を比較する：I=S=H 曖昧
// ✅ AnyOfの最高順位の重複成功を比較する：I=S=H 曖昧
// ✅ AnyOfの一致長が異なる同順位候補を全体一致で比較する：I=S=H 成功
// ✅ AnyOfの低順位の重複より高順位の成功を選ぶ：I=S=H 成功
// ✅ 内側と外側のAnyOfの優先値を比較する：I=S=H 成功
// ✅ 反復ごとにAnyOfの候補を選ぶ：I=S=H 成功
// ✅ Optional内のAnyOfの曖昧性を比較する：I=S=H 曖昧
// ✅ AnyOfのToken候補で空白を読み飛ばす：I=S=H 成功
// ✅ AnyOfでUnicodeの候補を選ぶ：I=S=H 成功
// ✅ AnyOfの全候補が先頭で失敗する：I=S=H 不一致
// ✅ AnyOfの同じ最遠位置の期待値を比較する：I=S=H 不一致
// ✅ AnyOfの最も先で失敗した候補の期待値を返す：I=S=H 不一致
// ✅ AnyOfの選択後に後続が失敗した場合を比較する：I=S=H 成功
// 一覧ここまで

import Spellu


// AnyOfのCompatible Tests。
// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
@Suite struct SyntaxAnyOfTests {

	@Test func 一候補のAnyOfが一致する() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOfの先頭候補だけが一致する() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOfの後続候補だけが一致する() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func ラベルのないAnyOfの候補が一致する() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOfで後に書いた高順位の候補を選ぶ() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.low) {
					Fragment(label: "low", "a")
				}
				Branch(.high) {
					Fragment(label: "high", "a")
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
				Tree(label: "high", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "high", "a")
			},
		)
	}

	@Test func AnyOfで先に書いた高順位の候補を選ぶ() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.high) {
					Fragment(label: "high", "a")
				}
				Branch(.low) {
					Fragment(label: "low", "a")
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
				Tree(label: "high", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "high", "a")
			},
		)
	}

	@Test func AnyOfの通常候補よりmiddleの候補を優先する() throws {
		let rule = Syntax {
			AnyOf {
				Fragment(label: "default", "a")
				Branch(.middle) {
					Fragment(label: "preferred", "a")
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
				Tree(label: "preferred", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "preferred", "a")
			},
		)
	}

	@Test func AnyOfの高順位候補が部分一致で失敗した場合を比較する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.high) {
					Fragment("ab")
					Fragment("x")
				}
				Branch(.low) {
					Fragment(label: "fallback", "a")
				}
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

	@Test func 同順位のAnyOfで一候補だけが成功した場合を比較する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.high) {
					Fragment(label: "selected", "a")
				}
				Branch(.high) {
					Fragment("ab")
					Fragment("x")
				}
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
				Tree(label: "selected", "a")
				Tree(label: "tail", "bc") {
					Tree("b")
					Tree("c")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "selected", "a")
				Tree(label: "tail", "bc")
			},
		)
	}

	@Test func AnyOfのBranchを複数の要素で構成する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.high) {
					Fragment(label: "A", "a")
					Fragment(label: "B", "b")
				}
				Branch(.low) {
					Fragment(label: "C", "c")
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

	@Test func AnyOfの候補をラベルのないSequenceでまとめる() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOfの候補をラベル付きSequenceでまとめる() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOf全体をラベル付きSequenceで包む() throws {
		let rule = Syntax {
			Sequence(label: "selected") {
				AnyOf {
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

	@Test func 空のBranchを高順位で選ぶAnyOfを比較する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.high) {
				}
				Branch(.low) {
					Fragment(label: "A", "a")
				}
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
				Tree(label: "tail", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "tail", "a")
			},
		)
	}

	@Test func 空のAnyOfを比較する() throws {
		let rule = Syntax {
			AnyOf {}
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

	@Test func AnyOfの同順位の重複成功を比較する() throws {
		let rule = Syntax {
			AnyOf {
				Fragment(label: "left", "a")
				Fragment(label: "right", "a")
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
			error: .ambiguousPath(precedence: 0),
		)
	}

	@Test func AnyOfの最高順位の重複成功を比較する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.low) {
					Fragment(label: "low", "a")
				}
				Branch(.high) {
					Fragment(label: "left", "a")
				}
				Branch(.high) {
					Fragment(label: "right", "a")
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
			error: .ambiguousPath(precedence: 100),
		)
	}

	@Test func AnyOfの一致長が異なる同順位候補を全体一致で比較する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.middle) {
					Fragment(label: "short", "a")
				}
				Branch(.middle) {
					Fragment(label: "long", "ab")
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

	@Test func AnyOfの低順位の重複より高順位の成功を選ぶ() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.low) {
					Fragment(label: "left", "a")
				}
				Branch(.low) {
					Fragment(label: "right", "a")
				}
				Branch(.high) {
					Fragment(label: "high", "a")
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
				Tree(label: "high", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "high", "a")
			},
		)
	}

	@Test func 内側と外側のAnyOfの優先値を比較する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.low) {
					AnyOf {
						Branch(.high) {
							Fragment(label: "inner", "a")
						}
					}
				}
				Branch(.middle) {
					Fragment(label: "outer", "a")
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
				Tree(label: "inner", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "inner", "a")
			},
		)
	}

	@Test func 反復ごとにAnyOfの候補を選ぶ() throws {
		let rule = Syntax {
			Repeat(2...2) {
				AnyOf {
					Branch(.high) {
						Fragment(label: "A", "a")
					}
					Branch(.low) {
						Fragment(label: "B", "b")
					}
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

	@Test func Optional内のAnyOfの曖昧性を比較する() throws {
		let rule = Syntax {
			Optional {
				AnyOf {
					Fragment(label: "left", "a")
					Fragment(label: "right", "a")
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
			error: .ambiguousPath(precedence: 0),
		)
	}

	@Test func AnyOfのToken候補で空白を読み飛ばす() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOfでUnicodeの候補を選ぶ() throws {
		let rule = Syntax {
			AnyOf {
				Fragment(label: "猫", "猫")
				Fragment(label: "犬", "犬")
			}
		}

		let source: String
		= "猫"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "猫", "猫")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "猫", "猫")
			},
		)
	}

	@Test func AnyOfの全候補が先頭で失敗する() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOfの同じ最遠位置の期待値を比較する() throws {
		let rule = Syntax {
			AnyOf {
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

	@Test func AnyOfの最も先で失敗した候補の期待値を返す() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.high) {
					Fragment("ab")
					Fragment(label: "C", "c")
				}
				Branch(.low) {
					Fragment(label: "X", "x")
				}
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

	@Test func AnyOfの選択後に後続が失敗した場合を比較する() throws {
		let rule = Syntax {
			AnyOf {
				Branch(.high) {
					Fragment(label: "long", "ab")
				}
				Branch(.low) {
					Fragment(label: "short", "a")
				}
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

}
