// テストケース一覧（検証対象と期待値）
// I: Interpreter、S: Sakuya、H: Hoori。
// =は共通の期待値、/は異なる期待値。
// 成功は木、不一致は不一致エラー、曖昧は曖昧性エラー。
// ✅は検証対象の期待値が一致、⚠️は異なる期待値。
// 特記のない成功・エラーはasisとcompactの両方を検証する。
//
// 集計：実行3件、一致3件、差異0件。
// ✅ eagerは先頭の回の本文の選択を回数より先に比べる：I=S=H 成功（asisのみ）
// ✅ reluctantは先頭の回の本文の選択を回数より先に比べる：I=S=H 成功（asisのみ）
// ✅ 後続がある場合も先頭の回から比べる：I=S=H 成功（asisのみ）
// 一覧ここまで

import Testing
import Spellu


/// 反復の回数が違う候補は、先頭の回から順に、継続の選択と本文の選択を比べる。
/// 左再帰に展開しても、回数を先に比べないことを確かめる。
@Suite struct SyntaxRepeatOrderTests {

	private let engines: [Spellu.Engine] = [
		.interpreter, .sakuya, .hoori,
	]

	private func render(_ node: SourceNode) -> String {
		let name: String = node.label.string ?? "_"
		if node.parts.isEmpty { return "\(name)\"\(node.string)\"" }
		return "\(name)(" + node.parts.map(render).joined(separator: " ") + ")"
	}

	private func check(_ rule: Syntax, _ source: String, _ expected: String) throws {
		for engine: Spellu.Engine in engines {
			let tree: SourceNode = try source.wholeMatch(
				engine: engine, strategy: .asis, spaces: [], as: { rule.ir },
			)
			#expect(render(tree) == expected, "\(engine)")
		}
	}

	@Test func eagerは先頭の回の本文の選択を回数より先に比べる() throws {
		try check(Syntax {
			Repeat {
				ChoiceOf {
					Sequence(label: "two") { Fragment("aa") }
					Sequence(label: "one") { Fragment("a") }
				}
			}
		}, "aa", #"$(two(#and(_"a" _"a")))"#)
	}

	@Test func reluctantは先頭の回の本文の選択を回数より先に比べる() throws {
		try check(Syntax {
			Repeat(behavior: .reluctant) {
				ChoiceOf {
					Sequence(label: "one") { Fragment("a") }
					Sequence(label: "two") { Fragment("aa") }
				}
			}
		}, "aa", #"$(one(_"a") one(_"a"))"#)
	}

	@Test func 後続がある場合も先頭の回から比べる() throws {
		try check(Syntax {
			Repeat {
				ChoiceOf {
					Sequence(label: "two") { Fragment("aa") }
					Sequence(label: "one") { Fragment("a") }
				}
			}
			Sequence(label: "tail") { Repeat(0...1) { Fragment("a") } }
		}, "aaa", #"$(two(#and(_"a" _"a")) one(_"a") tail"")"#)
	}

}
