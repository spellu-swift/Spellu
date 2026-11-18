import Basis


/// Tokenの反復動作。
public enum TokenRepetitionBehavior : Hashable, Sendable {

	/// 多い回数から試し、後続が失敗したら戻る。
	/// （積極的、『欲張り』）
	case eager

	/// 少ない回数から試し、後続の成立に必要なら増やす。
	/// （気が進まない、『渋々』）
	case reluctant

	/// 多く消費して確定し、成功した反復の内部へ戻らない。
	/// （出しゃばらない、『独り占め』）
	case possessive

}


/// 字句解析IR。
public struct TokenIR : Hashable, Sendable {
	
	public enum Factor : Hashable, Sendable {
		case character(CharacterSet)
		case string(String)
		case alternative([TokenIR])
		case sequence([TokenIR])
	}
	
	///  要素
	public var factor: Factor
	
	/// 繰り返し回数
	public var amount: Amount

	/// 繰り返しの試行順と後戻りの可否
	public var behavior: TokenRepetitionBehavior

	/// Unicode Simple Case Folding を有効にするかを表すフラグ
	public var caseInsensitive: Bool?

	/// 期待値の表現
	public var expect: String?
	
	@inlinable
	package init(
		factor: Factor,
		amount: Amount = .exactly(1),
		behavior: TokenRepetitionBehavior = .eager,
		caseInsensitive: Bool? = nil,
	) {
		self.factor = factor
		self.amount = amount
		self.behavior = behavior
		self.caseInsensitive = caseInsensitive
	}
	
}


extension TokenIR {

	@inlinable
	public init(
		_ string: String,
	) {
		self.init(factor: .string(string), amount: .exactly(1))
	}
	
}


extension TokenIR {

	@inlinable
	public static func character(
		_ patterns: CharacterPattern...,
		amount: Amount = .exactly(1),
		behavior: TokenRepetitionBehavior = .eager,
	) -> Self {
		.init(
			factor: .character(.include(patterns)),
			amount: amount,
			behavior: behavior,
		)
	}
	
	@inlinable
	public static func character(
		_ set: CharacterSet,
		amount: Amount = .exactly(1),
		behavior: TokenRepetitionBehavior = .eager,
	) -> Self {
		.init(
			factor: .character(set),
			amount: amount,
			behavior: behavior,
		)
	}
	
	@inlinable
	public static func string(
		_ string: String,
		amount: Amount = .exactly(1),
		behavior: TokenRepetitionBehavior = .eager,
		caseInsensitive: Bool? = nil,
	) -> Self {
		.init(
			factor: .string(string),
			amount: amount,
			behavior: behavior,
			caseInsensitive: caseInsensitive,
		)
	}
	
	@inlinable
	public static func alternative(
		_ rules: [TokenIR],
		amount: Amount = .exactly(1),
		behavior: TokenRepetitionBehavior = .eager,
	) -> Self {
		.init(
			factor: .alternative(rules),
			amount: amount,
			behavior: behavior,
		)
	}
	
	@inlinable
	public static func sequence(
		_ rules: [TokenIR],
		amount: Amount = .exactly(1),
		behavior: TokenRepetitionBehavior = .eager,
	) -> Self {
		.init(
			factor: .sequence(rules),
			amount: amount,
			behavior: behavior,
		)
	}
	
}


extension TokenIR {
	
	public func `repeat`(
		_ range: some RangeExpression<Int>,
		behavior: TokenRepetitionBehavior = .eager,
	) -> TokenIR {
		.init(
			factor: self.factor,
			amount: range.asAmount,
			behavior: behavior,
			caseInsensitive: self.caseInsensitive,
		)
	}

	public func ignoresCase(
		_ flag: Bool = true,
	) -> TokenIR {
		.init(
			factor: self.factor,
			amount: self.amount,
			behavior: self.behavior,
			caseInsensitive: flag,
		)
	}

}
