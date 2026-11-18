// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行20件、一致20件、差異0件。
// ✅ 空のSequenceが空入力に一致する：I=S=H 成功
// ✅ 一要素のSequenceが一致する：I=S=H 成功
// ✅ Sequenceの複数要素を一つの字句として出力する：I=S=H 成功
// ✅ Sequenceを含むTokenにラベルを付ける：I=S=H 成功
// ✅ Sequenceを含む一時ラベル付きTokenのcompact出力を比較する：I=S=H 成功
// ✅ 入れ子のSequenceが一致する：I=S=H 成功
// ✅ 空のSequenceから後続へ進む：I=S=H 成功
// ✅ Sequence先頭の空リテラルの結果を比較する：I=S=H 成功
// ✅ Sequence末尾の空リテラルの結果を比較する：I=S=H 成功
// ✅ Sequenceが先頭で不一致になる：I=S=H 不一致
// ✅ Sequenceの後続の不一致位置を比較する：I=S=H 不一致
// ✅ Sequenceの途中でEOFになる：I=S=H 不一致
// ✅ Sequenceの後に余分な入力が残る：I=S=H 不一致
// ✅ Sequence内部の空白を読み飛ばさない：I=S=H 不一致
// ✅ Sequenceで空白を明示的に読む：I=S=H 成功
// ✅ Sequenceで日本語と絵文字を読む：I=S=H 成功
// ✅ Sequenceの大小文字指定を内部で上書きする：I=S=H 成功
// ✅ Sequence内部で大小文字を区別した要素が失敗する：I=S=H 不一致
// ✅ Sequence内部のChoiceOfを後続から選び直す：I=S=H 成功
// ✅ Sequence内部のOptionalを省略する：I=S=H 成功
// 一覧ここまで

import Spellu


// 字句ルールのSequenceのCompatible Tests。
// TokenのBuilder内に置き、4構成のasis/compactの実出力を比較する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct TokenSequenceTests {

	@Test func 空のSequenceが空入力に一致する() throws {
		let rule = Syntax {
			Token {
				Sequence {
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

	@Test func 一要素のSequenceが一致する() throws {
		let rule = Syntax {
			Token {
				Sequence {
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

	@Test func Sequenceの複数要素を一つの字句として出力する() throws {
		let rule = Syntax {
			Token {
				Sequence {
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
				Tree("ab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Sequenceを含むTokenにラベルを付ける() throws {
		let rule = Syntax {
			Token(label: "pair") {
				Sequence {
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
				Tree(label: "pair", "ab")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", "ab")
			},
		)
	}

	@Test func Sequenceを含む一時ラベル付きTokenのcompact出力を比較する() throws {
		let rule = Syntax {
			Token(label: "#pair") {
				Sequence {
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
				Tree(label: "#pair", "ab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 入れ子のSequenceが一致する() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					Sequence {
						"b"
						"c"
					}
				}
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

	@Test func 空のSequenceから後続へ進む() throws {
		let rule = Syntax {
			Token {
				Sequence {
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

	@Test func Sequence先頭の空リテラルの結果を比較する() throws {
		let rule = Syntax {
			Token {
				Sequence {
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
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Sequence末尾の空リテラルの結果を比較する() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					""
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

	@Test func Sequenceが先頭で不一致になる() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					"b"
				}
			}
		}

		let source: String
		= "xb"

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

	@Test func Sequenceの後続の不一致位置を比較する() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"ab"
					"c"
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

	@Test func Sequenceの途中でEOFになる() throws {
		let rule = Syntax {
			Token {
				Sequence {
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
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("b")],
			),
		)
	}

	@Test func Sequenceの後に余分な入力が残る() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					"b"
				}
			}
		}

		let source: String
		= "abx"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
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

	@Test func Sequence内部の空白を読み飛ばさない() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					"b"
				}
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

	@Test func Sequenceで空白を明示的に読む() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					" "
					"b"
				}
			}
		}

		let source: String
		= "a b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a b")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Sequenceで日本語と絵文字を読む() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"日本"
					"🙂"
				}
			}
		}

		let source: String
		= "日本🙂"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("日本🙂")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Sequenceの大小文字指定を内部で上書きする() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					"b".ignoresCase(false)
				}.ignoresCase()
			}
		}

		let source: String
		= "Ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("Ab")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Sequence内部で大小文字を区別した要素が失敗する() throws {
		let rule = Syntax {
			Token {
				Sequence {
					"a"
					"b".ignoresCase(false)
				}.ignoresCase()
			}
		}

		let source: String
		= "AB"

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

	@Test func Sequence内部のChoiceOfを後続から選び直す() throws {
		let rule = Syntax {
			Token {
				Sequence {
					ChoiceOf {
						"ab"
						"a"
					}
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

	@Test func Sequence内部のOptionalを省略する() throws {
		let rule = Syntax {
			Token {
				Sequence {
					Optional {
						"a"
					}
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

}
