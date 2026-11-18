// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行21件、一致21件、差異0件。
// ✅ 一文字のStringが一致する：I=S=H 成功
// ✅ 複数文字のStringが一致する：I=S=H 成功
// ✅ 日本語と絵文字を含むStringが一致する：I=S=H 成功
// ✅ 結合文字を含むStringが一致する：I=S=H 成功
// ✅ 合成済み文字と結合文字列の照合を比較する：I=S=H 不一致
// ✅ Stringは既定で大小文字を区別する：I=S=H 不一致
// ✅ 空のStringの結果を比較する：I=S=H 成功
// ✅ Stringが先頭で不一致になる：I=S=H 不一致
// ✅ Stringの途中の不一致位置を比較する：I=S=H 不一致
// ✅ Stringの途中でEOFになる：I=S=H 不一致
// ✅ UnicodeのStringの途中の不一致位置を比較する：I=S=H 不一致
// ✅ 改行後のStringの不一致位置を比較する：I=S=H 不一致
// ✅ Stringの後に余分な入力が残る：I=S=H 不一致
// ✅ 先頭に空白があるStringの結果を比較する：I=S=H 成功
// ✅ Stringの末尾の空白を本文の範囲へ含めない：I=S=H 成功
// ✅ Stringの本文に含まれる空白を保持する：I=S=H 成功
// ✅ Stringの本文に含まれる改行を保持する：I=S=H 成功
// ✅ 隣接するStringを空白なしで読む：I=S=H 成功
// ✅ 隣接するStringの間に空白がある場合を比較する：I=S=H 成功
// ✅ 空のStringから後続のStringへ進む場合を比較する：I=S=H 成功
// ✅ Stringの後に空のStringがある場合を比較する：I=S=H 成功
// 一覧ここまで

import Spellu


// 構文ルールのStringのCompatible Tests。
// 各ケースで文字列リテラル版とString型変数版を同じ期待値で確認する。
// 期待値は3エンジンのasis/compactの実出力から採取する。
@Suite struct SyntaxStringTests {

	@Test func 一文字のStringが一致する() throws {
		let text: String
		= "a"

		let rules = [
			Syntax {
				"a"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "a"

		for rule: Syntax in rules {
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
	}

	@Test func 複数文字のStringが一致する() throws {
		let text: String
		= "spellu"

		let rules = [
			Syntax {
				"spellu"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "spellu"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree("spellu")
				},
				compact: Tree(label: "$", source),
			)
		}
	}

	@Test func 日本語と絵文字を含むStringが一致する() throws {
		let text: String
		= "日本🙂"

		let rules = [
			Syntax {
				"日本🙂"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "日本🙂"

		for rule: Syntax in rules {
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
	}

	@Test func 結合文字を含むStringが一致する() throws {
		let text: String
		= "e\u{301}"

		let rules = [
			Syntax {
				"e\u{301}"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "e\u{301}"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree("e\u{301}")
				},
				compact: Tree(label: "$", source),
			)
		}
	}

	@Test func 合成済み文字と結合文字列の照合を比較する() throws {
		let text: String
		= "é"

		let rules = [
			Syntax {
				"é"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "e\u{301}"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				error: .unexpected(
					source: .temporary(source),
					offset: 0,
					line: 1,
					column: 1,
					expects: [.literal("é")],
				),
			)
		}
	}

	@Test func Stringは既定で大小文字を区別する() throws {
		let text: String
		= "swift"

		let rules = [
			Syntax {
				"swift"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "Swift"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				error: .unexpected(
					source: .temporary(source),
					offset: 0,
					line: 1,
					column: 1,
					expects: [.literal("swift")],
				),
			)
		}
	}

	@Test func 空のStringの結果を比較する() throws {
		let text: String
		= ""

		let rules = [
			Syntax {
				""
			},
			Syntax {
				text
			},
		]

		let source: String
		= ""

		for rule: Syntax in rules {

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
	}

	@Test func Stringが先頭で不一致になる() throws {
		let text: String
		= "abc"

		let rules = [
			Syntax {
				"abc"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "xbc"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				error: .unexpected(
					source: .temporary(source),
					offset: 0,
					line: 1,
					column: 1,
					expects: [.literal("abc")],
				),
			)
		}
	}

	@Test func Stringの途中の不一致位置を比較する() throws {
		let text: String
		= "abc"

		let rules = [
			Syntax {
				"abc"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "abX"

		for rule: Syntax in rules {
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
	}

	@Test func Stringの途中でEOFになる() throws {
		let text: String
		= "abc"

		let rules = [
			Syntax {
				"abc"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "ab"

		for rule: Syntax in rules {
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
	}

	@Test func UnicodeのStringの途中の不一致位置を比較する() throws {
		let text: String
		= "日本語"

		let rules = [
			Syntax {
				"日本語"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "日本X"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				error: .unexpected(
					source: .temporary(source),
					offset: 6,
					line: 1,
					column: 3,
					expects: [.literal("語")],
				),
			)
		}
	}

	@Test func 改行後のStringの不一致位置を比較する() throws {
		let text: String
		= "ab\ncd"

		let rules = [
			Syntax {
				"ab\ncd"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "ab\ncX"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				error: .unexpected(
					source: .temporary(source),
					offset: 4,
					line: 2,
					column: 2,
					expects: [.literal("d")],
				),
			)
		}
	}

	@Test func Stringの後に余分な入力が残る() throws {
		let text: String
		= "a"

		let rules = [
			Syntax {
				"a"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "ab"

		for rule: Syntax in rules {
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
	}

	@Test func 先頭に空白があるStringの結果を比較する() throws {
		let text: String
		= "a"

		let rules = [
			Syntax {
				"a"
			},
			Syntax {
				text
			},
		]

		let source: String
		= " a"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: "a",
				asis: Tree(label: "$", "a") {
					Tree("a")
				},
				compact: Tree(label: "$", "a"),
			)
		}
	}

	@Test func Stringの末尾の空白を本文の範囲へ含めない() throws {
		let text: String
		= "a"

		let rules = [
			Syntax {
				"a"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "a "

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: "a",
				asis: Tree(label: "$", "a") {
					Tree("a")
				},
				compact: Tree(label: "$", "a"),
			)
		}
	}

	@Test func Stringの本文に含まれる空白を保持する() throws {
		let text: String
		= "a b"

		let rules = [
			Syntax {
				"a b"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "a b"

		for rule: Syntax in rules {
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
	}

	@Test func Stringの本文に含まれる改行を保持する() throws {
		let text: String
		= "a\nb"

		let rules = [
			Syntax {
				"a\nb"
			},
			Syntax {
				text
			},
		]

		let source: String
		= "a\nb"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree("a\nb")
				},
				compact: Tree(label: "$", source),
			)
		}
	}

	@Test func 隣接するStringを空白なしで読む() throws {
		let text1: String
		= "a"

		let text2: String
		= "b"

		let rules = [
			Syntax {
				"a"
				"b"
			},
			Syntax {
				text1
				text2
			},
		]

		let source: String
		= "ab"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree("a")
					Tree("b")
				},
				compact: Tree(label: "$", source),
			)
		}
	}

	@Test func 隣接するStringの間に空白がある場合を比較する() throws {
		let text1: String
		= "a"

		let text2: String
		= "b"

		let rules = [
			Syntax {
				"a"
				"b"
			},
			Syntax {
				text1
				text2
			},
		]

		let source: String
		= "a b"

		for rule: Syntax in rules {
			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree("a")
					Tree("b")
				},
				compact: Tree(label: "$", source),
			)
		}
	}

	@Test func 空のStringから後続のStringへ進む場合を比較する() throws {
		let text1: String
		= ""

		let text2: String
		= "a"

		let rules = [
			Syntax {
				""
				"a"
			},
			Syntax {
				text1
				text2
			},
		]

		let source: String
		= "a"

		for rule: Syntax in rules {

			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree("")
					Tree("a")
				},
				compact: Tree(label: "$", source),
			)
		}
	}

	@Test func Stringの後に空のStringがある場合を比較する() throws {
		let text1: String
		= "a"

		let text2: String
		= ""

		let rules = [
			Syntax {
				"a"
				""
			},
			Syntax {
				text1
				text2
			},
		]

		let source: String
		= "a"

		for rule: Syntax in rules {

			try compatibleTest(
				[.interpreter, .sakuya, .hoori],
				rule: rule,
				source: source,
				match: source,
				asis: Tree(label: "$", source) {
					Tree("a")
					Tree("")
				},
				compact: Tree(label: "$", source),
			)
		}
	}

}
