// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行31件、一致31件、差異0件。
// ✅ Enclosureの本文を省略する：I=S=H 成功
// ✅ Enclosureの本文に一要素が一致する：I=S=H 成功
// ✅ Enclosureの本文を複数回繰り返す：I=S=H 成功
// ✅ Enclosureの本文にラベルを付けない：I=S=H 成功
// ✅ Enclosureの一回分を複数のルールで構成する：I=S=H 成功
// ✅ Enclosureの本文をラベルのないSequenceで包む：I=S=H 成功
// ✅ Enclosureの本文をラベル付きSequenceで包む：I=S=H 成功
// ✅ Enclosure全体をラベル付きSequenceで包む：I=S=H 成功
// ✅ Enclosure内のTokenの間の空白を読み飛ばす：I=S=H 成功
// ✅ Enclosureを入れ子にする：I=S=H 成功
// ✅ Enclosure内にListを置く：I=S=H 成功
// ✅ 複数文字の区切りでEnclosureを囲む：I=S=H 成功
// ✅ 同じ文字の区切りでEnclosureを囲む：I=S=H 成功
// ✅ EnclosureでUnicode文字を囲む：I=S=H 成功
// ✅ Enclosureの前後にルールを置く：I=S=H 成功
// ✅ 本文の定義が空のEnclosureに一致する：I=S=H 成功
// ✅ Enclosureの開始区切りがないと失敗する：I=S=H 不一致
// ✅ Enclosureの終了区切りがないと失敗する：I=S=H 不一致
// ✅ Enclosureの終了区切りが異なると失敗する：I=S=H 不一致
// ✅ Enclosureの本文の部分一致に失敗する：I=S=H 不一致
// ✅ Enclosure内に未定義の要素があると失敗する：I=S=H 不一致
// ✅ Enclosureの本文と終了区切りが重なる：I=S=H 成功
// ✅ Enclosureの固定回数0では本文を読まず閉じる：I=S=H 成功
// ✅ Enclosureの範囲の下限と上限に一致する：I=S=H 成功
// ✅ Enclosureの固定回数2に一致する：I=S=H 成功
// ✅ Enclosureの本文が下限に届かなければ失敗する：I=S=H 不一致
// ✅ Enclosureの本文が上限を超えれば閉じ側で失敗する：I=S=H 不一致
// ✅ Enclosureの選好に応じて本文と閉じ側へ文字を分配する：I=S=H 成功
// ✅ 複数構文要素の開閉で本文を囲みラベルを保持する：I=S=H 成功
// ✅ 複数要素の開き側が途中で失敗した位置を比較する：I=S=H 不一致
// ✅ 複数要素の閉じ側が途中で失敗した位置を比較する：I=S=H 不一致
// 一覧ここまで

import Spellu



// EnclosureのCompatible Tests。
// 4エンジンのasis/compactを実行して採取した木とエラーを記載する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
// String版の区切りはasisで#opener/#closerとして出力する。
// 構文版の区切りは指定された構文のラベルを確認する。
@Suite struct SyntaxEnclosureTests {

	@Test func Enclosureの本文を省略する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "[]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
			},
		)
	}

	@Test func Enclosureの本文に一要素が一致する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "[a]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "A", "a")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Enclosureの本文を複数回繰り返す() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "[aaa]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Enclosureの本文にラベルを付けない() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment("a")
			}
		}

		let source: String
		= "[aa]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree("a")
				Tree("a")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
			},
		)
	}

	@Test func Enclosureの一回分を複数のルールで構成する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
		}

		let source: String
		= "[abab]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "A", "a")
				Tree(label: "B", "b")
				Tree(label: "A", "a")
				Tree(label: "B", "b")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func Enclosureの本文をラベルのないSequenceで包む() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Sequence {
					Fragment(label: "A", "a")
					Fragment("b")
				}
			}
		}

		let source: String
		= "[abab]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "#and", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
				Tree(label: "#and", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Enclosureの本文をラベル付きSequenceで包む() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Sequence(label: "pair") {
					Fragment(label: "A", "a")
					Fragment("b")
				}
			}
		}

		let source: String
		= "[abab]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
				}
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
				}
			},
		)
	}

	@Test func Enclosure全体をラベル付きSequenceで包む() throws {
		let rule = Syntax {
			Sequence(label: "enclosed") {
				Enclosure("[", "]") {
					Fragment(label: "A", "a")
				}
			}
		}

		let source: String
		= "[aa]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "enclosed", "[aa]") {
					Tree(label: "#opener", "[")
					Tree(label: "A", "a")
					Tree(label: "A", "a")
					Tree(label: "#closer", "]")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "enclosed", "[aa]") {
					Tree(label: "A", "a")
					Tree(label: "A", "a")
				}
			},
		)
	}

	@Test func Enclosure内のTokenの間の空白を読み飛ばす() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Token(label: "A", "a")
			}
		}

		let source: String
		= "[ a a ]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Enclosureを入れ子にする() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				AnyOf {
					Token(label: "A", "a")
					Enclosure("(", ")") {
						Token(label: "B", "b")
					}
				}
			}
		}

		let source: String
		= "[a(bb)a]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "A", "a")
				Tree(label: "#opener", "(")
				Tree(label: "B", "b")
				Tree(label: "B", "b")
				Tree(label: "#closer", ")")
				Tree(label: "A", "a")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
				Tree(label: "B", "b")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Enclosure内にListを置く() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				List(2...2, lastSeparator: .deny) {
					Token(label: "A", "a")
				} separator: {
					Token(",")
				}
			}
		}

		let source: String
		= "[a,a]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 複数文字の区切りでEnclosureを囲む() throws {
		let rule = Syntax {
			Enclosure("/*", "*/") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "/*aa*/"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "/*")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "#closer", "*/")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 同じ文字の区切りでEnclosureを囲む() throws {
		let rule = Syntax {
			Enclosure("\"", "\"") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "\"aa\""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "\"")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "#closer", "\"")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func EnclosureでUnicode文字を囲む() throws {
		let rule = Syntax {
			Enclosure("「", "」") {
				Fragment(label: "字", "あ")
			}
		}

		let source: String
		= "「ああ」"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "「")
				Tree(label: "字", "あ")
				Tree(label: "字", "あ")
				Tree(label: "#closer", "」")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "字", "あ")
				Tree(label: "字", "あ")
			},
		)
	}

	@Test func Enclosureの前後にルールを置く() throws {
		let rule = Syntax {
			Fragment(label: "before", "x")
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
			Fragment(label: "after", "y")
		}

		let source: String
		= "x[a]y"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "before", "x")
				Tree(label: "#opener", "[")
				Tree(label: "A", "a")
				Tree(label: "#closer", "]")
				Tree(label: "after", "y")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "before", "x")
				Tree(label: "A", "a")
				Tree(label: "after", "y")
			},
		)
	}

	@Test func 本文の定義が空のEnclosureに一致する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
			}
		}

		let source: String
		= "[]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
			},
		)
	}

	@Test func Enclosureの開始区切りがないと失敗する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "a]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.literal("[")],
			),
		)
	}

	@Test func Enclosureの終了区切りがないと失敗する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "[a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("]"), .literal("a")],
			),
		)
	}

	@Test func Enclosureの終了区切りが異なると失敗する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "[a)"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("]"), .literal("a")],
			),
		)
	}

	@Test func Enclosureの本文の部分一致に失敗する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
		}

		let source: String
		= "[a]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
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

	@Test func Enclosure内に未定義の要素があると失敗する() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "A", "a")
			}
		}

		let source: String
		= "[b]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("]"), .literal("a")],
			),
		)
	}

	@Test func Enclosureの本文と終了区切りが重なる() throws {
		let rule = Syntax {
			Enclosure("[", "]") {
				Fragment(label: "item") {
					ChoiceOf {
						"a"
						"]"
					}
				}
			}
		}

		let source: String
		= "[a]"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#opener", "[")
				Tree(label: "item", "a")
				Tree(label: "#closer", "]")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "item", "a")
			},
		)
	}

}


extension SyntaxEnclosureTests {

	@Test func Enclosureの固定回数0では本文を読まず閉じる() throws {
		let rule = Syntax {
			Enclosure("[", "]", 0...0) { Fragment(label: "A", "a") }
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[]", match: "[]",
			asis: Tree(label: "$", "[]") {
				Tree(label: "#opener", "[")
				Tree(label: "#closer", "]")
			}, compact: Tree(label: "$", "[]"))
	}

	@Test(arguments: ["[a]", "[aa]"])
	func Enclosureの範囲の下限と上限に一致する(source: String) throws {
		let rule = Syntax {
			Enclosure("[", "]", 1...2) { Fragment(label: "A", "a") }
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: source, match: source,
			asis: Tree(label: "$", source) {
				source == "[aa]"
					? [Tree(label: "#opener", "["), Tree(label: "A", "a"),
						Tree(label: "A", "a"), Tree(label: "#closer", "]")]
					: [Tree(label: "#opener", "["), Tree(label: "A", "a"),
						Tree(label: "#closer", "]")]
			}, compact: Tree(label: "$", source) {
				source == "[aa]"
					? [Tree(label: "A", "a"), Tree(label: "A", "a")]
					: [Tree(label: "A", "a")]
			})
	}

	@Test func Enclosureの固定回数2に一致する() throws {
		let rule = Syntax {
			Enclosure(2...2) { Fragment(label: "A", "a") }
			opener: { Fragment("[") }
			closer: { Fragment("]") }
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[aa]", match: "[aa]",
			asis: Tree(label: "$", "[aa]") {
				Tree("[")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree("]")
			}, compact: Tree(label: "$", "[aa]") {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			})
	}

	@Test func Enclosureの本文が下限に届かなければ失敗する() throws {
		let rule = Syntax {
			Enclosure("[", "]", 2...3) { Fragment("a") }
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[a]", error: .unexpected(source: .temporary("[a]"),
				offset: 2, line: 1, column: 3, expects: [.literal("a")]))
	}

	@Test func Enclosureの本文が上限を超えれば閉じ側で失敗する() throws {
		let rule = Syntax {
			Enclosure("[", "]", 1...2) { Fragment("a") }
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[aaa]", error: .unexpected(source: .temporary("[aaa]"),
				offset: 3, line: 1, column: 4, expects: [.literal("]")]))
	}

	@Test(arguments: [SyntaxRepetitionBehavior.eager, .reluctant])
	func Enclosureの選好に応じて本文と閉じ側へ文字を分配する(
		behavior: SyntaxRepetitionBehavior,
	) throws {
		let rule = Syntax {
			Enclosure(0...2, behavior: behavior) { Fragment(label: "A", "a") }
			opener: { Fragment("[") }
			closer: {
				Repeat { Fragment(label: "C", "a") }
				Fragment("!")
			}
		}
		let label: String = behavior == .reluctant ? "C" : "A"
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[aa!", match: "[aa!",
			asis: Tree(label: "$", "[aa!") {
				Tree("[")
				Tree(label: label, "a")
				Tree(label: label, "a")
				Tree("!")
			}, compact: Tree(label: "$", "[aa!") {
				Tree(label: label, "a")
				Tree(label: label, "a")
			})
	}

	@Test func 複数構文要素の開閉で本文を囲みラベルを保持する() throws {
		let rule = Syntax {
			Enclosure(1...2) { Fragment(label: "A", "a") }
			opener: {
				Fragment(label: "O1", "[")
				ChoiceOf { Fragment(label: "O2", "<"); Fragment("{") }
			}
			closer: {
				Fragment(label: "C1", ">")
				Fragment(label: "C2", "]")
			}
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[<aa>]", match: "[<aa>]",
			asis: Tree(label: "$", "[<aa>]") {
				Tree(label: "O1", "[")
				Tree(label: "O2", "<")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "C1", ">")
				Tree(label: "C2", "]")
			}, compact: Tree(label: "$", "[<aa>]") {
				Tree(label: "O1", "[")
				Tree(label: "O2", "<")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "C1", ">")
				Tree(label: "C2", "]")
			})
	}

	@Test func 複数要素の開き側が途中で失敗した位置を比較する() throws {
		let rule = Syntax {
			Enclosure(0...1) { Fragment("a") }
			opener: { Fragment("["); Fragment("<") }
			closer: { Fragment(">"); Fragment("]") }
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[?", error: .unexpected(source: .temporary("[?"),
				offset: 1, line: 1, column: 2, expects: [.literal("<")]))
	}

	@Test func 複数要素の閉じ側が途中で失敗した位置を比較する() throws {
		let rule = Syntax {
			Enclosure(1...1) { Fragment("a") }
			opener: { Fragment("["); Fragment("<") }
			closer: { Fragment(">"); Fragment("]") }
		}
		try compatibleTest([.interpreter, .sakuya, .hoori], rule: rule,
			source: "[<a>?", error: .unexpected(source: .temporary("[<a>?"),
				offset: 4, line: 1, column: 5, expects: [.literal("]")]))
	}

}
