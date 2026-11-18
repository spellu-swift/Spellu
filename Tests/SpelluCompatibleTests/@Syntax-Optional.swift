// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行9件、一致9件、差異0件。
// ✅ Optionalが一致する：I=S=H 成功
// ✅ Optionalを省略する：I=S=H 成功
// ✅ 先頭のOptionalだけが一致する：I=S=H 成功
// ✅ 後続のOptionalだけが一致する：I=S=H 成功
// ✅ 両方のOptionalが一致する：I=S=H 成功
// ✅ 両方のOptionalを省略する：I=S=H 成功
// ✅ Optional内部の部分一致に失敗する：I=S=H 成功
// ✅ Optional内部の複数要素が一致する：I=S=H 成功
// ✅ Optional内部が空である：I=S=H 成功
// 一覧ここまで

import Spellu


// OptionalのCompatible Tests。
// 各ケースの対象エンジンでasis/compactを実行し、採取した木を期待値に記載する。
@Suite struct SyntaxOptionalTests {

	@Test func Optionalが一致する() throws {
		let rule = Syntax {
			Optional {
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

	@Test func Optionalを省略する() throws {
		let rule = Syntax {
			Optional {
				Fragment(label: "A", "a")
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

	@Test func 先頭のOptionalだけが一致する() throws {
		let rule = Syntax {
			Optional {
				Fragment(label: "A", "a")
			}
			Optional {
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

	@Test func 後続のOptionalだけが一致する() throws {
		let rule = Syntax {
			Optional {
				Fragment(label: "A", "a")
			}
			Optional {
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

	@Test func 両方のOptionalが一致する() throws {
		let rule = Syntax {
			Optional {
				Fragment(label: "A", "a")
			}
			Optional {
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
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func 両方のOptionalを省略する() throws {
		let rule = Syntax {
			Optional {
				Fragment(label: "A", "a")
			}
			Optional {
				Fragment(label: "B", "b")
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

	@Test func Optional内部の部分一致に失敗する() throws {
		let rule = Syntax {
			Optional {
				Fragment(label: "A", "a")
				Fragment(label: "B", "b")
			}
			Fragment(label: "C", "a")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "C", "a")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "C", "a")
			},
		)

	}

	@Test func Optional内部の複数要素が一致する() throws {
		let rule = Syntax {
			Optional {
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
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
			compact: Tree(label: "$", source) {
				Tree(label: "A", "a")
				Tree(label: "B", "b")
			},
		)
	}

	@Test func Optional内部が空である() throws {
		let rule = Syntax {
			Optional {}
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

}
