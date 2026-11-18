import SpelluLex


// 対象API: 全7case、min/max/decrement/asRange/asRangeExpression、
// RangeExpression.asAmount、Equatable/Hashable。
// 0・1・有限・無上限・Int.max、負の実行時上限、
// 範囲表現の型と相互変換の正規化を確認する。
@Suite struct AmountTests {

	@Test(arguments: amountBounds)
	func 全ての数量の最小値と最大値を返す(
		_ amount: Amount,
		_ minimum: Int,
		_ maximum: Int?,
	) {
		#expect(amount.min == minimum)
		#expect(amount.max == maximum)
	}

	@Test(arguments: [
		(Amount.zeroOrMore, Amount.zeroOrMore),
		(.oneOrMore, .zeroOrMore),
		(.zeroOrOne, .exactly(0)),
		(.exactly(1), .exactly(0)),
		(.exactly(3), .exactly(2)),
		(.nOrMore(1), .zeroOrMore),
		(.nOrMore(3), .nOrMore(2)),
		(.upToN(1), .upToN(0)),
		(.upToN(3), .upToN(2)),
		(.range(1, 3), .range(0, 2)),
		(.range(2, 2), .range(1, 1)),
		(.exactly(Int.max), .exactly(Int.max - 1)),
		(.nOrMore(Int.max), .nOrMore(Int.max - 1)),
		(.upToN(Int.max), .upToN(Int.max - 1)),
		(.range(Int.max - 1, Int.max), .range(Int.max - 2, Int.max - 1)),
	])
	func 減算は数量の種類と無上限を保つ(
		_ amount: Amount,
		_ expected: Amount,
	) {
		#expect(amount.decrement == expected)
	}

	@Test func 零の減算は飽和させず整数として減らす() {
		#expect(Amount.exactly(0).decrement == .exactly(-1))
		#expect(Amount.upToN(0).decrement == .upToN(-1))
		#expect(Amount.range(0, 1).decrement == .range(-1, 0))
		#expect(Amount.nOrMore(0).decrement == .nOrMore(-1))
	}

	@Test(arguments: [Int.min, -1, 0, 1, 4, 1000, Int.max])
	func 有限の数量範囲は実行時上限によって切り詰めない(
		_ limit: Int,
	) {
		let cases: [(Amount, ClosedRange<Int>)] = [
			(.zeroOrOne, 0...1), (.exactly(0), 0...0), (.exactly(3), 3...3),
			(.upToN(0), 0...0), (.upToN(4), 0...4),
			(.range(2, 5), 2...5), (.range(0, 1000), 0...1000),
			(.exactly(Int.max), Int.max...Int.max),
			(.range(Int.max - 1, Int.max), (Int.max - 1)...Int.max),
		]
		for (amount, expected) in cases {
			#expect(amount.asRange(limit) == expected)
		}
	}

	@Test(arguments: [
		(Amount.zeroOrMore, Int.min, 0...0),
		(.zeroOrMore, -1, 0...0),
		(.zeroOrMore, 0, 0...0),
		(.zeroOrMore, 4, 0...4),
		(.zeroOrMore, Int.max, 0...Int.max),
		(.oneOrMore, Int.min, 1...1),
		(.oneOrMore, 0, 1...1),
		(.oneOrMore, 1, 1...1),
		(.oneOrMore, 4, 1...4),
		(.oneOrMore, Int.max, 1...Int.max),
		(.nOrMore(3), -1, 3...3),
		(.nOrMore(3), 2, 3...3),
		(.nOrMore(3), 3, 3...3),
		(.nOrMore(3), 4, 3...4),
		(.nOrMore(Int.max), 0, Int.max...Int.max),
		(.nOrMore(Int.max), Int.max, Int.max...Int.max),
	])
	func 無上限の範囲を上限で閉じても最小値より小さくしない(
		_ amount: Amount,
		_ limit: Int,
		_ expected: ClosedRange<Int>,
	) {
		#expect(amount.asRange(limit) == expected)
	}

	@Test(arguments: amountBounds)
	func 範囲表現は端点と非有界側を表す(
		_ amount: Amount,
		_ minimum: Int,
		_ maximum: Int?,
	) {
		let expression: any RangeExpression<Int> = amount.asRangeExpression
		#expect(expression.contains(minimum))
		if case .upToN = amount {
			// ...nは下限を持たない。数量としての下限0はminが保持する。
			#expect(expression.contains(Int.min))
		} else {
			#expect(!expression.contains(minimum - 1))
		}
		if let maximum {
			#expect(expression.contains(maximum))
			if maximum < Int.max {
				#expect(!expression.contains(maximum + 1))
			}
		} else {
			#expect(expression.contains(Int.max))
		}
	}

	@Test func 範囲表現は有限範囲と片側範囲の型を維持する() {
		#expect((Amount.zeroOrMore.asRangeExpression
			as? PartialRangeFrom<Int>)?.lowerBound == 0)
		#expect((Amount.oneOrMore.asRangeExpression
			as? PartialRangeFrom<Int>)?.lowerBound == 1)
		#expect((Amount.nOrMore(3).asRangeExpression
			as? PartialRangeFrom<Int>)?.lowerBound == 3)
		#expect(Amount.zeroOrOne.asRangeExpression
			as? ClosedRange<Int> == 0...1)
		#expect(Amount.exactly(2).asRangeExpression
			as? ClosedRange<Int> == 2...2)
		#expect((Amount.upToN(3).asRangeExpression
			as? PartialRangeThrough<Int>)?.upperBound == 3)
		#expect(Amount.range(2, 5).asRangeExpression
			as? ClosedRange<Int> == 2...5)
	}

	@Test func 標準の各範囲型を数量へ変換する() {
		let cases: [(any RangeExpression<Int>, Amount)] = [
			(0..<1, .exactly(0)), (2..<3, .exactly(2)),
			(0..<3, .upToN(2)), (2..<5, .range(2, 4)),
			(0...0, .exactly(0)), (2...2, .exactly(2)),
			(0...3, .upToN(3)), (2...5, .range(2, 5)),
			(..<1, .upToN(0)), (...0, .upToN(0)),
			(0..., .zeroOrMore), (1..., .oneOrMore), (2..., .nOrMore(2)),
			((Int.max - 1)..<Int.max, .exactly(Int.max - 1)),
			(Int.max...Int.max, .exactly(Int.max)),
			(..<Int.max, .upToN(Int.max - 1)),
			(...Int.max, .upToN(Int.max)),
			(Int.max..., .nOrMore(Int.max)),
		]
		for (range, expected) in cases {
			#expect(range.asAmount == expected)
		}
	}

	@Test(arguments: [
		(Amount.zeroOrMore, Amount.zeroOrMore),
		(.oneOrMore, .oneOrMore),
		(.zeroOrOne, .upToN(1)),
		(.exactly(0), .exactly(0)),
		(.exactly(2), .exactly(2)),
		(.nOrMore(0), .zeroOrMore),
		(.nOrMore(1), .oneOrMore),
		(.nOrMore(3), .nOrMore(3)),
		(.upToN(0), .upToN(0)),
		(.upToN(3), .upToN(3)),
		(.range(0, 0), .exactly(0)),
		(.range(0, 3), .upToN(3)),
		(.range(2, 2), .exactly(2)),
		(.range(2, 5), .range(2, 5)),
	])
	func 範囲から数量への変換は表現を正規化しても上下限を保つ(
		_ amount: Amount,
		_ canonical: Amount,
	) {
		let converted: Amount = amount.asRangeExpression.asAmount
		#expect(converted == canonical)
		#expect(converted.min == amount.min)
		#expect(converted.max == amount.max)
	}

	@Test func 同じ数量は等しく範囲が同じでもcaseが違えば区別する() {
		let values: Set<Amount> = [
			.zeroOrMore, .zeroOrMore, .oneOrMore, .zeroOrOne,
			.exactly(2), .nOrMore(2), .upToN(2), .range(1, 2),
		]
		#expect(values.count == 7)
		#expect(values.contains(.exactly(2)))
		#expect(!values.contains(.exactly(3)))
		#expect(Amount.exactly(2) != .range(2, 2))
		#expect(Amount.oneOrMore != .nOrMore(1))
	}

}


private let amountBounds: [(Amount, Int, Int?)] = [
	(.zeroOrMore, 0, nil), (.oneOrMore, 1, nil), (.zeroOrOne, 0, 1),
	(.exactly(0), 0, 0), (.exactly(2), 2, 2),
	(.nOrMore(0), 0, nil), (.nOrMore(1), 1, nil), (.nOrMore(3), 3, nil),
	(.upToN(0), 0, 0), (.upToN(3), 0, 3),
	(.range(0, 0), 0, 0), (.range(2, 5), 2, 5),
	(.exactly(Int.max), Int.max, Int.max),
	(.nOrMore(Int.max), Int.max, nil),
	(.upToN(Int.max), 0, Int.max),
]


