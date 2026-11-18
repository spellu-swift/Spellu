// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行24件、一致24件、差異0件。
// ✅ 空のChoiceOfの結果を比較する：I=S=H 不一致
// ✅ 一候補のChoiceOfが一致する：I=S=H 成功
// ✅ ChoiceOfの先頭候補が一致する：I=S=H 成功
// ✅ ChoiceOfの後続候補が一致する：I=S=H 成功
// ✅ ChoiceOfの全候補が不一致になる：I=S=H 不一致
// ✅ ChoiceOfの最遠位置で失敗した候補の期待値を比較する：I=S=H 不一致
// ✅ ChoiceOfの同じ最遠位置で失敗した複数の期待値を比較する：I=S=H 不一致
// ✅ 短い候補を先に置いたChoiceOfの後に入力が残る：I=S=H 不一致
// ✅ 長い候補を先に置いたChoiceOfが一致する：I=S=H 成功
// ✅ 短い候補のChoiceOfから後続へ進む：I=S=H 成功
// ✅ 長い候補を後続のために短い候補へ選び直す：I=S=H 成功
// ✅ 短い候補を後続のために長い候補へ選び直す：I=S=H 成功
// ✅ ChoiceOf内部の部分一致を巻き戻して別候補へ進む：I=S=H 成功
// ✅ 同じ内容のChoiceOf候補が重複しても一致する：I=S=H 成功
// ✅ 空のSequence候補を選んで後続へ進む：I=S=H 成功
// ✅ 空のSequence候補を先に置くと入力が残る：I=S=H 不一致
// ✅ ChoiceOf先頭の空リテラル候補の結果を比較する：I=S=H 不一致
// ✅ ChoiceOfの空リテラル一候補を空入力で比較する：I=S=H 成功
// ✅ Optional内部のChoiceOfが後続候補を選ぶ：I=S=H 成功
// ✅ ChoiceOfの大小文字指定を復帰後も保持する：I=S=H 成功
// ✅ ChoiceOfでUnicode候補を後続から選び直す：I=S=H 成功
// ✅ ChoiceOfで文字クラスの候補を選ぶ：I=S=H 成功
// ✅ ChoiceOfを含むTokenにラベルを付ける：I=S=H 成功
// ✅ ChoiceOfを含む一時ラベル付きTokenのcompact出力を比較する：I=S=H 成功
// 一覧ここまで

import Spellu


// 字句ルールのChoiceOfのCompatible Tests。
// TokenのBuilder内に置き、4構成のasis/compactの実出力を比較する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct TokenChoiceOfTests {

	@Test func 空のChoiceOfの結果を比較する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
				}
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

	@Test func 一候補のChoiceOfが一致する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
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
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOfの先頭候補が一致する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
					"b"
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
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOfの後続候補が一致する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
					"b"
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
				Tree("b")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOfの全候補が不一致になる() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
					"b"
				}
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

	@Test func ChoiceOfの最遠位置で失敗した候補の期待値を比較する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"abc"
					"axy"
				}
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

	@Test func ChoiceOfの同じ最遠位置で失敗した複数の期待値を比較する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"abc"
					"abd"
				}
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
				expects: [.literal("c"), .literal("d")],
			),
		)
	}

	@Test func 短い候補を先に置いたChoiceOfの後に入力が残る() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
					"ab"
				}
			}
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

	@Test func 長い候補を先に置いたChoiceOfが一致する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"ab"
					"a"
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
				Tree("ab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 短い候補のChoiceOfから後続へ進む() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
					"ab"
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
				Tree("ab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 長い候補を後続のために短い候補へ選び直す() throws {
		let rule = Syntax {
			Token {
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
				Tree("ab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 短い候補を後続のために長い候補へ選び直す() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
					"ab"
				}
				"c"
			}
		}

		let source: String
		= "abc"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("abc")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOf内部の部分一致を巻き戻して別候補へ進む() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					Sequence {
						"ab"
						"x"
					}
					"a"
				}
				"bc"
			}
		}

		let source: String
		= "abc"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("abc")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 同じ内容のChoiceOf候補が重複しても一致する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"a"
					"a"
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
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 空のSequence候補を選んで後続へ進む() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					Sequence {
					}
					"a"
				}
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

	@Test func 空のSequence候補を先に置くと入力が残る() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					Sequence {
					}
					"a"
				}
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
				offset: 0,
				line: 1,
				column: 1,
				expects: [.eos],
			),
		)
	}

	@Test func ChoiceOf先頭の空リテラル候補の結果を比較する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					""
					"a"
				}
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
				offset: 0,
				line: 1,
				column: 1,
				expects: [.eos],
			),
		)
	}

	@Test func ChoiceOfの空リテラル一候補を空入力で比較する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					""
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
			asis: Tree(label: "$", source) {
				Tree("")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Optional内部のChoiceOfが後続候補を選ぶ() throws {
		let rule = Syntax {
			Token {
				Optional {
					ChoiceOf {
						"a"
						"b"
					}
				}
				"c"
			}
		}

		let source: String
		= "bc"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("bc")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOfの大小文字指定を復帰後も保持する() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"ab".ignoresCase(false)
					"a"
				}.ignoresCase()
				"B"
			}
		}

		let source: String
		= "AB"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("AB")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOfでUnicode候補を後続から選び直す() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					"ςb"
					"σ"
				}.ignoresCase()
				"b"
			}
		}

		let source: String
		= "Σb"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("Σb")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOfで文字クラスの候補を選ぶ() throws {
		let rule = Syntax {
			Token {
				ChoiceOf {
					ASCII.digit
					"a"
				}
			}
		}

		let source: String
		= "7"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("7")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ChoiceOfを含むTokenにラベルを付ける() throws {
		let rule = Syntax {
			Token(label: "value") {
				ChoiceOf {
					"a"
					"b"
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
				Tree(label: "value", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "value", "b")
			},
		)
	}

	@Test func ChoiceOfを含む一時ラベル付きTokenのcompact出力を比較する() throws {
		let rule = Syntax {
			Token(label: "#value") {
				ChoiceOf {
					"a"
					"b"
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
				Tree(label: "#value", "b")
			},
			compact: Tree(label: "$", source),
		)
	}

}
