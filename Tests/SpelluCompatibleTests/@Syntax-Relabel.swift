// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行7件、一致7件、差異0件。
// ✅ Fragmentのlabelを付け直す：I=S=H 成功
// ✅ Stringを指定したFragmentのlabelを付け直す：I=S=H 成功
// ✅ Tokenのlabelを付け直す：I=S=H 成功
// ✅ Wordのlabelを付け直す：I=S=H 成功
// ✅ Sequenceのlabelを付け直して子を保持する：I=S=H 成功
// ✅ Optionalが返すlabelを付け直す：I=S=H 成功
// ✅ Triviaのlabelを付け直す：I=S=H 成功
// ー Repeatが返す各要素のlabelを付け直す：コメントアウト中（実行対象外）
// ー Listが返す要素と区切りのlabelを付け直す：コメントアウト中（実行対象外）
// ー Enclosureが返す子のlabelを付け直す：コメントアウト中（実行対象外）
// ー ChoiceOfの子のlabelを付け直す：コメントアウト中（実行対象外）
// ー AnyOfの子のlabelを付け直す：コメントアウト中（実行対象外）
// 一覧ここまで

import Spellu


// RelabelのCompatible Tests。
// Relabelは構文ルールではなく、構文要素の子にlabelを付け直す操作である。
@Suite struct SyntaxRelabelTests {

	@Test func Fragmentのlabelを付け直す() throws {
		let rule = Syntax {
			Fragment(label: "before", "a").as(label: "CHARACTER")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
			compact: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
		)
	}

	@Test func Stringを指定したFragmentのlabelを付け直す() throws {
		let rule = Syntax {
			Fragment("a").as(label: "CHARACTER")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
			compact: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
		)
	}

	@Test func Tokenのlabelを付け直す() throws {
		let rule = Syntax {
			Token(label: "before", "a").as(label: "CHARACTER")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
			compact: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
		)
	}

	@Test func Wordのlabelを付け直す() throws {
		let rule: Syntax = .init {
			Word(label: "before", "if") {
				ASCII.word.repeat(1...)
			}.as(label: "CHARACTER")
		}

		let source: String
		= "if"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
			compact: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
		)
	}

	@Test func Sequenceのlabelを付け直して子を保持する() throws {
		let rule: Syntax = .init {
			Sequence(label: "before") {
				Fragment(label: "left", "a")
				Fragment(label: "right", "b")
			}.as(label: "CHARACTER")
		}

		let source: String
		= "ab"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source) {
					Tree(label: "left", "a")
					Tree(label: "right", "b")
				}
			},
			compact: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source) {
					Tree(label: "left", "a")
					Tree(label: "right", "b")
				}
			},
		)
	}

	@Test func Optionalが返すlabelを付け直す() throws {
		let rule: Syntax = .init {
			Optional {
				Fragment(label: "before", "a")
			}.as(label: "CHARACTER")
		}

		let source: String
		= "a"

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
			compact: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
		)
	}

//	@Test func Repeatが返す各要素のlabelを付け直す() throws {
//		let rule: Syntax = .init {
//			Repeat(2...2) {
//				Fragment(label: "before", "a")
//			}.as(label: "CHARACTER")
//		}
//
//		let source: String
//		= "aa"
//
//		try compatibleTest(
//			[.interpreter, .sakuya, .hoori],
//			rule: rule,
//			source: source,
//			match: source,
//			asis: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", "a")
//				Tree(label: "CHARACTER", "a")
//			},
//			compact: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", "a")
//				Tree(label: "CHARACTER", "a")
//			},
//		)
//	}
//
//	@Test func Listが返す要素と区切りのlabelを付け直す() throws {
//		let rule: Syntax = .init {
//			List(lastSeparator: .deny) {
//				Fragment(label: "item", "a")
//			} separator: {
//				Fragment(label: "separator", ",")
//			}.as(label: "CHARACTER")
//		}
//
//		let source: String
//		= "a,a"
//
//		try compatibleTest(
//			[.interpreter, .sakuya, .hoori],
//			rule: rule,
//			source: source,
//			match: source,
//			asis: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", "a")
//				Tree(label: "CHARACTER", ",")
//				Tree(label: "CHARACTER", "a")
//			},
//			compact: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", "a")
//				Tree(label: "CHARACTER", ",")
//				Tree(label: "CHARACTER", "a")
//			},
//		)
//
//	}
//
//	@Test func Enclosureが返す子のlabelを付け直す() throws {
//		let rule: Syntax = .init {
//			Enclosure("[", "]") {
//				Fragment(label: "before", "a")
//			}.as(label: "CHARACTER")
//		}
//
//		let source: String
//		= "[a]"
//
//		try compatibleTest(
//			[.v2],
//			rule: rule,
//			source: source,
//			match: source,
//			asis: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", "[")
//				Tree(label: "CHARACTER", "a")
//				Tree(label: "CHARACTER", "]")
//			},
//			compact: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", "[")
//				Tree(label: "CHARACTER", "a")
//				Tree(label: "CHARACTER", "]")
//			},
//		)
//		try compatibleTest(
//			[.interpreter, .sakuya, .hoori],
//			rule: rule,
//			source: source,
//			match: source,
//			asis: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", source)
//			},
//			compact: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", source)
//			},
//		)
//	}
//
//	@Test(arguments: ["a", "b"])
//	func ChoiceOfの子のlabelを付け直す(
//		source: String,
//	) throws {
//		let rule: Syntax = .init {
//			ChoiceOf {
//				"a"
//				"b"
//			}.as(label: "CHARACTER")
//		}
//
//		try compatibleTest(
//			[.interpreter, .sakuya, .hoori],
//			rule: rule,
//			source: source,
//			match: source,
//			asis: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", source)
//			},
//			compact: Tree(label: "$", source) {
//				Tree(label: "CHARACTER", source)
//			},
//		)
//	}
//
//	@Test func AnyOfの子のlabelを付け直す() throws {
//		let rule = Syntax {
//			AnyOf {
//				"a"
//				"b"
//			}.as(label: "CHARACTER")
//				.as(label: "GG")
//		}
//
//		let source: String
//		= "a"
//
//		try compatibleTest(
//			[.interpreter, .sakuya, .hoori],
//			rule: rule,
//			source: source,
//			match: source,
//			asis: Tree(label: "$", source) {
//				Tree(label: "GG", source)
//			},
//			compact: Tree(label: "$", source) {
//				Tree(label: "GG", source)
//			},
//		)
//	}

	@Test func Triviaのlabelを付け直す() throws {
		let rule = Syntax {
			Trivia.as(label: "CHARACTER")
		}

		let spaces: [SpacePattern]
		= [.space]

		let source: String
		= " "

		try compatibleTest(
			[.interpreter, .sakuya, .hoori],
			rule: rule,
			spaces: spaces,
			source: source,
			match: source,
			asis: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
			compact: Tree(label: "$", source) {
				Tree(label: "CHARACTER", source)
			},
		)
	}

}
