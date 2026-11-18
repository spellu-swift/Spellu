// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行31件、一致31件、差異0件。
// ✅ 空入力でのListの出力を比較する：I=S=H 成功
// ✅ Listの要素が一つだけ一致する：I=S=H 成功
// ✅ ラベルのない要素と区切りを並べる：I=S=H 成功
// ✅ Listの末尾の区切りを許可する：I=S=H 成功
// ✅ Listの末尾の区切りを省略する：I=S=H 成功
// ✅ 末尾区切り禁止のListを空入力で比較する：I=S=H 成功
// ✅ 末尾の区切りを禁止したListに要素を並べる：I=S=H 成功
// ✅ 末尾の区切りを禁止したListは末尾区切りで失敗する：I=S=H 不一致
// ✅ Listの区切りにもラベルを付ける：I=S=H 成功
// ✅ Listの一要素を複数のルールで構成する：I=S=H 成功
// ✅ Listの区切りを複数のルールで構成する：I=S=H 成功
// ✅ Listの要素をラベルのないSequenceで包む：I=S=H 成功
// ✅ Listの要素をラベル付きSequenceで包む：I=S=H 成功
// ✅ List全体をラベル付きSequenceで包む：I=S=H 成功
// ✅ List内のTokenの間の空白を読み飛ばす：I=S=H 成功
// ✅ ListでUnicode文字と区切りを読む：I=S=H 成功
// ✅ 最小個数1のListは空入力に一致しない：I=S=H 不一致
// ✅ 下限のみ指定したListが最小個数に一致する：I=S=H 成功
// ✅ Listの個数が下限に届かない：I=S=H 不一致
// ✅ 上限を指定したListが上限に一致する：I=S=H 成功
// ✅ Listの上限を超える入力を比較する：I=S=H 不一致
// ✅ 末尾区切り禁止のListの上限を超える要素が残る：I=S=H 不一致
// ✅ 固定個数のListに末尾区切りを付ける：I=S=H 成功
// ✅ 固定個数のListの要素が不足する：I=S=H 不一致
// ✅ 範囲を指定したListが下限に一致する：I=S=H 成功
// ✅ 範囲を指定したListが上限に一致する：I=S=H 成功
// ✅ 個数0のListと後続ルールを比較する：I=S=H 成功
// ✅ Listの先頭の区切りを拒否する：I=S=H 不一致
// ✅ List内で区切りが続くと失敗する：I=S=H 不一致
// ✅ Listの要素の部分一致に失敗する：I=S=H 不一致
// ✅ Listの区切りの部分一致に失敗する：I=S=H 不一致
// 一覧ここまで

import Spellu


// ListのCompatible Tests。
// 各エンジンのasis/compactを実行して採取した木とエラーを記載する。
// 共通の出力は1回、異なる出力はエンジンごとのcompatibleTestで明示する。
@Suite struct SyntaxListTests {

	@Test func 空入力でのListの出力を比較する() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
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

	@Test func Listの要素が一つだけ一致する() throws {
		let rule = Syntax {
			List {
				Fragment("a")
			} separator: {
				Fragment(",")
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

	@Test func ラベルのない要素と区切りを並べる() throws {
		let rule = Syntax {
			List {
				Fragment("a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("a")
				Tree(",")
				Tree("a")
				Tree(",")
				Tree("a")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func Listの末尾の区切りを許可する() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a,"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
				Tree(",")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Listの末尾の区切りを省略する() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 末尾区切り禁止のListを空入力で比較する() throws {
		let rule = Syntax {
			List(lastSeparator: .deny) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
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

	@Test func 末尾の区切りを禁止したListに要素を並べる() throws {
		let rule = Syntax {
			List(lastSeparator: .deny) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 末尾の区切りを禁止したListは末尾区切りで失敗する() throws {
		let rule = Syntax {
			List(lastSeparator: .deny) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("a")],
			),
		)
	}

	@Test func Listの区切りにもラベルを付ける() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(label: "comma", ",")
			}
		}

		let source: String
		= "a,a,"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "comma", ",")
				Tree(label: "A", "a")
				Tree(label: "comma", ",")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "comma", ",")
				Tree(label: "A", "a")
				Tree(label: "comma", ",")
			},
		)
	}

	@Test func Listの一要素を複数のルールで構成する() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "ab,ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
				Tree(",")
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

	@Test func Listの区切りを複数のルールで構成する() throws {
		let rule = Syntax {
			List(lastSeparator: .deny) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(label: "comma", ",")
				Fragment(";")
			}
		}

		let source: String
		= "a,;a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "comma", ",")
				Tree(";")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "comma", ",")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Listの要素をラベルのないSequenceで包む() throws {
		let rule = Syntax {
			List {
				Sequence {
					Fragment(label: "A", "a")
					Fragment("b")
				}
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "ab,ab"

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
				Tree(",")
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

	@Test func Listの要素をラベル付きSequenceで包む() throws {
		let rule = Syntax {
			List {
				Sequence(label: "pair") {
					Fragment(label: "A", "a")
					Fragment("b")
				}
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "ab,ab"

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
				Tree(",")
				Tree(label: "pair", "ab") {
					Tree(label: "A", "a")
					Tree("b")
				}
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

	@Test func List全体をラベル付きSequenceで包む() throws {
		let rule = Syntax {
			Sequence(label: "items") {
				List {
					Fragment(label: "A", "a")
				} separator: {
					Fragment(",")
				}
			}
		}

		let source: String
		= "a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "items", "a,a") {
					Tree(label: "A", "a")
					Tree(",")
					Tree(label: "A", "a")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "items", "a,a") {
					Tree(label: "A", "a")
					Tree(label: "A", "a")
				}
			},
		)
	}

	@Test func List内のTokenの間の空白を読み飛ばす() throws {
		let rule = Syntax {
			List {
				Token(label: "A", "a")
			} separator: {
				Token(",")
			}
		}

		let source: String
		= "a , a ,"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
				Tree(",")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func ListでUnicode文字と区切りを読む() throws {
		let rule = Syntax {
			List {
				Fragment(label: "字", "あ")
			} separator: {
				Fragment("、")
			}
		}

		let source: String
		= "あ、あ、"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "字", "あ")
				Tree("、")
				Tree(label: "字", "あ")
				Tree("、")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "字", "あ")
				Tree(label: "字", "あ")
			},
		)
	}

	@Test func 最小個数1のListは空入力に一致しない() throws {
		let rule = Syntax {
			List(1...) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
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

	@Test func 下限のみ指定したListが最小個数に一致する() throws {
		let rule = Syntax {
			List(2...) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Listの個数が下限に届かない() throws {
		let rule = Syntax {
			List(2...) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
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
				expects: [.literal(",")],
			),
		)
	}

	@Test func 上限を指定したListが上限に一致する() throws {
		let rule = Syntax {
			List(...2) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func Listの上限を超える入力を比較する() throws {
		let rule = Syntax {
			List(...2) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
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

	@Test func 末尾区切り禁止のListの上限を超える要素が残る() throws {
		let rule = Syntax {
			List(...2, lastSeparator: .deny) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a,a"

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

	@Test func 固定個数のListに末尾区切りを付ける() throws {
		let rule = Syntax {
			List(2...2) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a,"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
				Tree(",")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 固定個数のListの要素が不足する() throws {
		let rule = Syntax {
			List(2...2) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
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
				expects: [.literal(",")],
			),
		)
	}

	@Test func 範囲を指定したListが下限に一致する() throws {
		let rule = Syntax {
			List(2...3) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 範囲を指定したListが上限に一致する() throws {
		let rule = Syntax {
			List(2...3) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,a,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
				Tree(",")
				Tree(label: "A", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "A", "a")
				Tree(label: "A", "a")
			},
		)
	}

	@Test func 個数0のListと後続ルールを比較する() throws {
		let rule = Syntax {
			List(0...0) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
			Fragment(label: "tail", "b")
		}

		let source: String
		= "b"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "tail", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "tail", "b")
			},
		)
	}

	@Test func Listの先頭の区切りを拒否する() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= ",a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 0,
				line: 1,
				column: 1,
				expects: [.literal("a"), .eos],
			),
		)
	}

	@Test func List内で区切りが続くと失敗する() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "a,,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal("a"), .eos],
			),
		)
	}

	@Test func Listの要素の部分一致に失敗する() throws {
		let rule = Syntax {
			List {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			} separator: {
				Fragment(",")
			}
		}

		let source: String
		= "ab,a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 4,
				line: 1,
				column: 5,
				expects: [.literal("b")],
			),
		)
	}

	@Test func Listの区切りの部分一致に失敗する() throws {
		let rule = Syntax {
			List(lastSeparator: .deny) {
				Fragment(label: "A", "a")
			} separator: {
				Fragment(label: "comma", ",")
				Fragment(label: "semicolon", ";")
			}
		}

		let source: String
		= "a,"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			error: .unexpected(
				source: .temporary(source),
				offset: 2,
				line: 1,
				column: 3,
				expects: [.literal(";")],
			),
		)
	}

}
