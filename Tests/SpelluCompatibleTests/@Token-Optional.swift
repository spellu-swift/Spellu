// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行22件、一致22件、差異0件。
// ✅ Optionalが一致する：I=S=H 成功
// ✅ Optionalを省略して空入力に一致する：I=S=H 成功
// ✅ Optionalを省略して後続へ進む：I=S=H 成功
// ✅ Optionalと後続が一致する：I=S=H 成功
// ✅ 両方のOptionalが一致する：I=S=H 成功
// ✅ 両方のOptionalを省略する：I=S=H 成功
// ✅ 先頭のOptionalだけが一致する：I=S=H 成功
// ✅ 後続のOptionalだけが一致する：I=S=H 成功
// ✅ Optional内部の複数要素が一致する：I=S=H 成功
// ✅ Optional内部の部分一致を巻き戻して後続へ進む：I=S=H 成功
// ✅ 一致したOptionalを後続のために省略し直す：I=S=H 成功
// ✅ Optionalと後続の両方で同じ文字を読む：I=S=H 成功
// ✅ 入れ子のOptionalを省略する：I=S=H 成功
// ✅ Optional内部が空である：I=S=H 成功
// ✅ Optional内部の空リテラルの結果を比較する：I=S=H 成功
// ✅ Optionalに一致しない余分な入力が残る：I=S=H 不一致
// ✅ 省略したOptionalの最遠失敗位置を比較する：I=S=H 不一致
// ✅ Optionalの大小文字指定を内部へ引き継ぐ：I=S=H 成功
// ✅ Optionalと後続の間の空白を読み飛ばさない：I=S=H 不一致
// ✅ Optionalを含むTokenの前後の空白を読み飛ばす：I=S=H 成功
// ✅ Optionalを含むTokenにラベルを付ける：I=S=H 成功
// ✅ Optionalを含む一時ラベル付きTokenのcompact出力を比較する：I=S=H 成功
// 一覧ここまで

import Spellu


// 字句ルールのOptionalのCompatible Tests。
// TokenのBuilder内に置き、4構成のasis/compactの実出力を比較する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct TokenOptionalTests {

	@Test func Optionalが一致する() throws {
		let rule = Syntax {
			Token {
				Optional {
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

	@Test func Optionalを省略して空入力に一致する() throws {
		let rule = Syntax {
			Token {
				Optional {
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

	@Test func Optionalを省略して後続へ進む() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
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

	@Test func Optionalと後続が一致する() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
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

	@Test func 両方のOptionalが一致する() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
				Optional {
					"b"
				}
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

	@Test func 両方のOptionalを省略する() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
				Optional {
					"b"
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

	@Test func 先頭のOptionalだけが一致する() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
				Optional {
					"b"
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

	@Test func 後続のOptionalだけが一致する() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
				Optional {
					"b"
				}
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

	@Test func Optional内部の複数要素が一致する() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
					"b"
				}
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

	@Test func Optional内部の部分一致を巻き戻して後続へ進む() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
					"b"
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

	@Test func 一致したOptionalを後続のために省略し直す() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
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

	@Test func Optionalと後続の両方で同じ文字を読む() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
				"a"
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

	@Test func 入れ子のOptionalを省略する() throws {
		let rule = Syntax {
			Token {
				Optional {
					Optional {
						"a"
					}
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

	@Test func Optional内部が空である() throws {
		let rule = Syntax {
			Token {
				Optional {
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

	@Test func Optional内部の空リテラルの結果を比較する() throws {
		let rule = Syntax {
			Token {
				Optional {
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

	@Test func Optionalに一致しない余分な入力が残る() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
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
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.eos],
			),
		)
	}

	@Test func 省略したOptionalの最遠失敗位置を比較する() throws {
		let rule = Syntax {
			Token {
				Optional {
					"ab"
					"c"
				}
				"ax"
			}
		}

		let source: String
		= "abX"

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
				expects: [.literal("c")],
			),
		)
	}

	@Test func Optionalの大小文字指定を内部へ引き継ぐ() throws {
		let rule = Syntax {
			Token {
				Optional {
					"Σ"
				}.ignoresCase()
				"!"
			}
		}

		let source: String
		= "ς!"

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("ς!")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Optionalと後続の間の空白を読み飛ばさない() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
				"b"
			}
		}

		let source: String
		= "a b"

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
				expects: [.literal("b")],
			),
		)
	}

	@Test func Optionalを含むTokenの前後の空白を読み飛ばす() throws {
		let rule = Syntax {
			Token {
				Optional {
					"a"
				}
				"b"
			}
		}

		let source: String
		= " ab "

		try compatibleTest(
			[
				.interpreter, .sakuya, .hoori,
			],
			rule: rule,
			source: source,
			match: "ab",
			asis: Tree(label: "$", "ab") {
				Tree("ab")
			},
			compact: Tree(label: "$", "ab"),
		)
	}

	@Test func Optionalを含むTokenにラベルを付ける() throws {
		let rule = Syntax {
			Token(label: "value") {
				Optional {
					"a"
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
				Tree(label: "value", "ab")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "value", "ab")
			},
		)
	}

	@Test func Optionalを含む一時ラベル付きTokenのcompact出力を比較する() throws {
		let rule = Syntax {
			Token(label: "#value") {
				Optional {
					"a"
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
				Tree(label: "#value", "b")
			},
			compact: Tree(label: "$", source),
		)
	}

}
