import SpelluCore


/// Sakuyaの解析ごとの安全上限。
/// 上限を超えるとsafetyStopで停止し、途中の候補を成功として返さない。
public struct SafetyLimits : Sendable {

	public static let `default`: Self = .init()

	public static let DEFAULT_MAX_SYNTAX_REPETITION: Int = 1000
	public static let DEFAULT_MAX_TOKEN_REPETITION: Int = 65535
	public static let DEFAULT_MAX_WORK: Int = 1_000_000
	public static let DEFAULT_MAX_RULE_ARRIVALS: Int = 4_096

	public static let MIN_SYNTAX_REPETITION: Int = 16
	public static let MIN_TOKEN_REPETITION: Int = 1024
	public static let MIN_WORK: Int = 1000
	public static let MIN_RULE_ARRIVALS: Int = 1

	/// nilは既定値。指定値は各最小値からInt.max - 1の範囲に収める。
	public init(
		maxSyntaxRepetition: Int? = nil,
		maxTokenRepetition: Int? = nil,
		maxWork: Int? = nil,
		maxRuleArrivals: Int? = nil,
	) {
		self.maxSyntaxRepetition = minmax(
			maxSyntaxRepetition ?? Self.DEFAULT_MAX_SYNTAX_REPETITION,
			min: Self.MIN_SYNTAX_REPETITION,
			max: Int.max - 1,
		)
		self.maxTokenRepetition = minmax(
			maxTokenRepetition ?? Self.DEFAULT_MAX_TOKEN_REPETITION,
			min: Self.MIN_TOKEN_REPETITION,
			max: Int.max - 1,
		)
		self.maxWork = minmax(
			maxWork ?? Self.DEFAULT_MAX_WORK,
			min: Self.MIN_WORK,
			max: Int.max - 1,
		)
		self.maxRuleArrivals = minmax(
			maxRuleArrivals ?? Self.DEFAULT_MAX_RULE_ARRIVALS,
			min: Self.MIN_RULE_ARRIVALS,
			max: Int.max - 1,
		)
	}

	/// 無消費の構文反復回数と、確定範囲の入れ子の上限。
	public let maxSyntaxRepetition: Int

	/// 字句ルールの繰り返し上限。
	public let maxTokenRepetition: Int

	/// 一回の解析の総作業量。探索・導出解決・木の具体化で共有する。
	public let maxWork: Int

	/// ルール呼び出し一つあたりの到達結果数。タグ環境の違いも数える。
	public let maxRuleArrivals: Int

}
