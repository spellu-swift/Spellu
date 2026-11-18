

extension SafetyLimits {

	public static let DEFAULT_MAX_SYNTAX_REPETITION: Int = 1000
	public static let DEFAULT_MAX_TOKEN_REPETITION: Int = 65535
	public static let DEFAULT_MAX_WORK: Int = 1_000_000

	public static let MIN_SYNTAX_REPETITION: Int = 16
	public static let MIN_TOKEN_REPETITION: Int = 1024
	public static let MIN_WORK: Int = 1000

}


public struct SafetyLimits : Sendable {

	public static let `default`: Self = .init()

	public init(
		maxSyntaxRepetition: Int? = nil,
		maxTokenRepetition: Int? = nil,
		maxWork: Int? = nil,
	) {
		self.maxSyntaxRepetition = minmax(
			maxSyntaxRepetition ?? SafetyLimits.DEFAULT_MAX_SYNTAX_REPETITION,
			min: SafetyLimits.MIN_SYNTAX_REPETITION,
			max: Int.max - 1,
		)
		self.maxTokenRepetition = minmax(
			maxTokenRepetition ?? SafetyLimits.DEFAULT_MAX_TOKEN_REPETITION,
			min: SafetyLimits.MIN_TOKEN_REPETITION,
			max: Int.max - 1,
		)
		self.maxWork = minmax(
			maxWork ?? SafetyLimits.DEFAULT_MAX_WORK,
			min: SafetyLimits.MIN_WORK,
			max: Int.max - 1,
		)
	}

	/// 構文ルールの繰り返し上限
	package let maxSyntaxRepetition: Int

	/// 字句ルールの繰り返し上限
	package let maxTokenRepetition: Int

	/// 実験エンジンの総作業量。構文Repeatの回数制限とは独立。
	package let maxWork: Int

}


