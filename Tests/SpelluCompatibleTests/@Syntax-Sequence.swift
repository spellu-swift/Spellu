// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行14件、一致14件、差異0件。
// ✅ 暗黙のSequence：I=S=H 成功
// ✅ ラベルなしのSequence：I=S=H 成功
// ✅ 一つの子にラベルがあるSequence：I=S=H 成功
// ✅ 両方の子にラベルがあるSequence：I=S=H 成功
// ✅ ラベル付きのSequence：I=S=H 成功
// ✅ 一時ラベル付きのSequence：I=S=H 成功
// ✅ 一要素のSequence：I=S=H 成功
// ✅ ラベル付きのSequenceを入れ子にする：I=S=H 成功
// ✅ ラベルなしのSequenceを入れ子にする：I=S=H 成功
// ✅ 空のSequence：I=S=H 成功
// ✅ ラベル付きの空のSequence：I=S=H 成功
// ✅ Sequence内のOptionalを省略する：I=S=H 成功
// ✅ Sequenceの先頭で不一致になる：I=S=H 不一致
// ✅ Sequenceの途中で不一致になる：I=S=H 不一致
// 一覧ここまで

import Spellu


// SequenceのCompatible Tests。
// 3エンジンのasis/compactの実出力を期待値に記載する。
@Suite struct SyntaxSequenceTests {

	@Test func 暗黙のSequence() throws {
		let rule = Syntax {
			Token("foo")
			Token("bar")
		}

		let source: String
		= "foo bar"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree("foo")
				Tree("bar")
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ラベルなしのSequence() throws {
		let rule = Syntax {
			Sequence {
				Token("foo")
				Token("bar")
			}
		}

		let source: String
		= "foo bar"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#and", source) {
					Tree("foo")
					Tree("bar")
				}
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func 一つの子にラベルがあるSequence() throws {
		let rule = Syntax {
			Sequence {
				Token(label: "A", "foo")
				Token("bar")
			}
		}

		let source: String
		= "foo bar"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#and", source) {
					Tree(label: "A", "foo")
					Tree("bar")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "foo")
			},
		)
	}

	@Test func 両方の子にラベルがあるSequence() throws {
		let rule = Syntax {
			Sequence {
				Token(label: "A", "foo")
				Token(label: "B", "bar")
			}
		}

		let source: String
		= "foo bar"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#and", source) {
					Tree(label: "A", "foo")
					Tree(label: "B", "bar")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "foo")
				Tree(label: "B", "bar")
			},
		)
	}

	@Test func ラベル付きのSequence() throws {
		let rule = Syntax {
			Sequence(label: "pair") {
				Token(label: "A", "foo")
				Token("bar")
			}
		}

		let source: String
		= "foo bar"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "pair", source) {
					Tree(label: "A", "foo")
					Tree("bar")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", source) {
					Tree(label: "A", "foo")
				}
			},
		)
	}

	@Test func 一時ラベル付きのSequence() throws {
		let rule = Syntax {
			Sequence(label: "#pair") {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
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
				Tree(label: "#pair", source) {
					Tree(label: "A", "a")
					Tree(label: "B", "b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func 一要素のSequence() throws {
		let rule = Syntax {
			Sequence {
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
				Tree(label: "#and", source) {
					Tree(label: "A", source)
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", source)
			},
		)
	}

	@Test func ラベル付きのSequenceを入れ子にする() throws {
		let rule = Syntax {
			Sequence(label: "outer") {
				Sequence(label: "inner") {
					Fragment(label: "A", "a")
				}
				Fragment(label: "B", "b")
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
				Tree(label: "outer", source) {
					Tree(label: "inner", "a") {
						Tree(label: "A", "a")
					}
					Tree(label: "B", "b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "outer", source) {
					Tree(label: "inner", "a") {
						Tree(label: "A", "a")
					}
					Tree(label: "B", "b")
				}
			},
		)
	}

	@Test func ラベルなしのSequenceを入れ子にする() throws {
		let rule = Syntax {
			Sequence {
				Sequence {
					Fragment(label: "A", "a")
				}
				Fragment(label: "B", "b")
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
				Tree(label: "#and", source) {
					Tree(label: "#and", "a") {
						Tree(label: "A", "a")
					}
					Tree(label: "B", "b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func 空のSequence() throws {
		let rule = Syntax {
			Sequence {}
		}

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "#and", source)
			},
			compact: Tree(label: "$", source),
		)
	}

	@Test func ラベル付きの空のSequence() throws {
		let rule = Syntax {
			Sequence(label: "empty") {}
		}

		let source: String
		= ""

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "empty", source)
			},
			compact: Tree(label: "$", source) {
				Tree(label: "empty", source)
			},
		)
	}

	@Test func Sequence内のOptionalを省略する() throws {
		let rule = Syntax {
			Sequence(label: "pair") {
				Optional { Fragment(label: "A", "a") }
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
				Tree(label: "pair", source) {
					Tree(label: "B", source)
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "pair", source) {
					Tree(label: "B", source)
				}
			},
		)
	}

	@Test func Sequenceの先頭で不一致になる() throws {
		let rule = Syntax {
			Sequence {
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
				expects: [.literal("a")],
			),
		)
	}

	@Test func Sequenceの途中で不一致になる() throws {
		let rule = Syntax {
			Sequence {
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
			error: .unexpected(
				source: .temporary(source),
				offset: 1,
				line: 1,
				column: 2,
				expects: [.literal("b")],
			),
		)
	}

}
