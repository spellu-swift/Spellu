@testable import SpelluLex


// 共通条件: 選択順、全Amount、eagerとreluctant、空成功、Unicode、長い入力。
// Matcher、汎用VM、最適化VMを同じパターン・入力・期待値・上限で確認する。
@Suite struct TokenMatchingSemanticsTests {

	@Test(arguments: TokenMatchingEngine.allCases)
	func ChoiceOfの順序を守り後続から別候補へ戻れる(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		checks.check([.alternative([.string("a"), .string("ab")])], "ab", "a")
		checks.check([.alternative([.string("ab"), .string("a")])], "ab", "ab")
		checks.check([.alternative([.string("ab"), .string("a")]), .string("b")], "ab", "ab")
		checks.check([
			.sequence([.sequence([.alternative([.string("abc"), .string("ab"), .string("a")])])]),
			.string("bc"),
		], "abc", "abc")
		checks.check([.alternative([.string("abc"), .string("ab"), .string("a")]), .string("bc")], "abx", nil)
	}

	@Test(arguments: [
		TokenRepetitionBehavior.eager, .reluctant,
	], TokenMatchingEngine.allCases)
	func 反復動作が消費量と後戻りを決める(
		_ behavior: TokenRepetitionBehavior,
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		let expected: String?
		= switch behavior {
			case .eager: "aaa"
			case .reluctant: "a"
			default: preconditionFailure("対象外の反復指定です")
		}
		checks.check([
			.string("a", amount: .zeroOrMore, behavior: behavior),
			.string("a"),
		], "aaa", expected)
		checks.check([
			.character(
				.include(.any("a")), amount: .zeroOrMore, behavior: behavior,
			),
			.string("a"),
		], "aaa", expected)
		checks.check([
			.sequence([.string("a")], amount: .zeroOrMore, behavior: behavior),
			.string("a"),
		], "aaa", expected)
		checks.check([
			.string("a", amount: .range(2, 3), behavior: behavior),
		], "aaaa", behavior == .reluctant ? "aa" : "aaa")
		checks.check([
			.string("a", amount: .range(2, 3), behavior: behavior),
		], "a", nil)
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func reluctantは直後の後続が成立するまでだけ読む(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		checks.check([
			.string("<"), .character(.all).repeat(0..., behavior: .reluctant),
			.string(">"),
		], "<x><y>", "<x>")
		checks.check([
			.string("<"), .character(.all).repeat(0...), .string(">"),
		], "<x><y>", "<x><y>")
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func Token全体の最長ではなく局所的な試行順を守る(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		checks.check([
			.string("a").repeat(0...), .string("ab").repeat(0...),
		], "aab", "aa")
		checks.check([
			.alternative([.string("aa"), .string("a")]).repeat(1..., behavior: .reluctant),
		], "aaa", "aa")

	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func 全てのAmountと実行時上限を扱う(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		let cases: [(Amount, String)] = [
			(.zeroOrMore, "aaa"), (.oneOrMore, "aaa"),
			(.zeroOrOne, "a"), (.exactly(0), ""), (.exactly(2), "aa"),
			(.nOrMore(2), "aaa"), (.upToN(2), "aa"), (.range(1, 2), "aa"),
		]
		for (amount, expected) in cases {
			checks.check(
				[.string("a", amount: amount)], "aaaa", expected, limit: 3,
			)
		}
		for behavior: TokenRepetitionBehavior in [
			.eager, .reluctant,
		] {
			checks.check([
				.string("a", amount: .oneOrMore, behavior: behavior),
				.string("!"),
			], "aaa!", nil, limit: 2)
			checks.check([
				.string("a", amount: .nOrMore(3), behavior: behavior),
			], "aaa!", nil, limit: 2)
			checks.check([
				.string("a", amount: .zeroOrMore, behavior: behavior),
			], "aaa", "", limit: 0)
		}
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func 固定回数でも内部ChoiceOfを復元する(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		let choice: TokenIR = .alternative([.string("aa"), .string("a")])
		checks.check([choice.repeat(2...2), .string("a")], "aaa", "aaa")

	}


	@Test(arguments: TokenMatchingEngine.allCases)
	func 最後の未完成反復を巻き戻す(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		let body: [TokenIR] = [.string("_"), .string("1")]
		for behavior: TokenRepetitionBehavior in [
			.eager, .reluctant,
		] {
			checks.check([
				.sequence(body, amount: .oneOrMore, behavior: behavior),
				.string("_"),
			], "_1_", "_1_")
			checks.check([
				.sequence(body, amount: .exactly(2), behavior: behavior),
			], "_1_", nil)
			checks.check([
				.string("_1", amount: .oneOrMore, behavior: behavior),
				.string("_"),
			], "_1_", "_1_")
		}
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func 空成功と空失敗を区別し不要な上限検査を先行しない(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		checks.check([.sequence([])], "a", "")
		checks.check([.sequence([])], "a", nil, limit: 0)
		checks.check([.string("")], "a", "")
		checks.check([.alternative([])], "a", nil)
		checks.check([.string("", amount: .zeroOrMore)], "a", "")
		checks.check([.alternative([], amount: .zeroOrMore)], "a", "")
		checks.check([.sequence([], amount: .zeroOrMore)], "a", "", limit: 0)
		checks.check([
			.sequence([.string("a").repeat(100...)], amount: .zeroOrMore),
		], "a", "", limit: 0)
		for behavior: TokenRepetitionBehavior in [
			.eager, .reluctant,
		] {
			checks.check([
				.sequence([], amount: .range(2, 3), behavior: behavior),
				.string("a"),
			], "a", "a")
			checks.check([
				.sequence([], amount: .zeroOrMore, behavior: behavior),
				.string("a"),
			], "a", "a")
		}
		checks.check([
			.alternative([.sequence([]), .string("a")]).repeat(0...), .string("b"),
		], "ab", "ab")
	}

	@Test(arguments: TokenMatchingEngine.allCases)
	func Unicodeと大小文字上書きを復帰後も維持する(
		engine: TokenMatchingEngine,
	) {
		let checks: TokenMatchingChecks = .init(engine: engine)
		checks.check([
			.sequence([.alternative([.string("ςb"), .string("σ")])]).ignoresCase(), .string("b"),
		], "Σb", "Σb")
		checks.check([
			.sequence([
				.alternative([.string("ab").ignoresCase(false), .string("a")])
			]).ignoresCase(),
			.string("B"),
		], "AB", "AB")
		checks.check([
			.string("k").ignoresCase().repeat(0...), .string("k!"),
		], "Kk!", "Kk!")
		checks.check([
			.string("kσ").ignoresCase().repeat(0...), .string("kς!"),
		], "KΣkς!", "KΣkς!")
		checks.check([
			.character(.any("Σ")).ignoresCase().repeat(0...),
			.string("ς!"),
		], "Σς!", "Σς!")
		checks.check([.string("é")], "e\u{301}", nil)
		checks.check([.string("ss", caseInsensitive: true)], "ß", nil)
	}

}
