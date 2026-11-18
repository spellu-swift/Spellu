import SpelluLex


// 対象API: TokenRepetitionBehavior、TokenIRの生成・設定、Repeat、
// TokenIR/String/CharacterClass.repeat、TokenIR.ignoresCase。
// eagerとreluctantの保存、既定値、回数・大小文字設定の保持を確認する。
@Suite struct TokenRepetitionBehaviorTests {

	@Test func 反復動作の既定値はeagerになる() {
		let patterns: [TokenIR] = [
			.init("a"),
			.string("a"),
			.character(.include(.any("a"))),
			.sequence([.string("a")]),
			.alternative([.string("a")]),
			.string("a").repeat(1...),
			.character(.include(.any(["a"]))).repeat(1...),
			TokenIR("a").repeat(1...),
			.sequence([.string("a")], amount: (1...).asAmount, behavior: .eager),
		]
		for pattern: TokenIR in patterns {
			#expect(pattern.behavior == .eager)
		}
	}

	@Test(arguments: [
		TokenRepetitionBehavior.eager, .reluctant,
	])
	func 各生成APIで反復動作を指定できる(
		_ behavior: TokenRepetitionBehavior,
	) {
		let patterns: [TokenIR] = [
			.string("a", amount: .range(1, 3), behavior: behavior),
			.character(
				.include(.any("a")),
				amount: .range(1, 3),
				behavior: behavior,
			),
			.sequence([.string("a")], amount: .range(1, 3), behavior: behavior),
			.alternative(
				[.string("a")],
				amount: .range(1, 3),
				behavior: behavior,
			),
			.string("a").repeat(1...3, behavior: behavior),
			.character(.include(.any("a"))).repeat(1...3, behavior: behavior),
			TokenIR("a").repeat(1...3, behavior: behavior),
			.sequence([.string("a")], amount: (1...3).asAmount, behavior: behavior),
		]
		for pattern: TokenIR in patterns {
			#expect(pattern.amount == .range(1, 3))
			#expect(pattern.behavior == behavior)
		}
	}

	@Test func 大小文字設定と反復動作を独立に保持する() {
		let pattern: TokenIR = .string("a").ignoresCase()
			.repeat(1..., behavior: .reluctant)
			.ignoresCase(false)
		#expect(pattern.caseInsensitive == false)
		#expect(pattern.behavior == .reluctant)
		#expect(pattern.amount == .oneOrMore)

		var changed: TokenIR = pattern
		changed.behavior = .eager
		#expect(changed.behavior == .eager)
		#expect(changed != pattern)
		#expect(Set([pattern, changed]).count == 2)
	}

}
