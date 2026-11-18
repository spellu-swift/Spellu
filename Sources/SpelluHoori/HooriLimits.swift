///
/// Hooriの安全上限
///
/// 上限を超えた解析は `SpelluError.safetyStop` で止まり、途中の候補を成功として返さない。
///
public struct HooriLimits : Equatable, Sendable {

	public static let `default`: Self = .init()

	public static let DEFAULT_MAX_TOKEN_REPETITION: Int = 65535
	public static let DEFAULT_MAX_BOUNDARY_DEPTH: Int = 1000
	public static let DEFAULT_MAX_EMPTY_REPETITION: Int = 1000
	public static let DEFAULT_MAX_WORK: Int = 1_000_000

	/// 省略した上限は既定値になる。負の値は0として扱う。
	public init(
		maxTokenRepetition: Int? = nil,
		maxBoundaryDepth: Int? = nil,
		maxEmptyRepetition: Int? = nil,
		maxWork: Int? = nil,
	) {
		self.maxTokenRepetition = max(
			0,
			maxTokenRepetition ?? Self.DEFAULT_MAX_TOKEN_REPETITION,
		)
		self.maxBoundaryDepth = max(
			0,
			maxBoundaryDepth ?? Self.DEFAULT_MAX_BOUNDARY_DEPTH,
		)
		self.maxEmptyRepetition = max(
			0,
			maxEmptyRepetition ?? Self.DEFAULT_MAX_EMPTY_REPETITION,
		)
		self.maxWork = max(
			0,
			maxWork ?? Self.DEFAULT_MAX_WORK,
		)
	}

	/// 字句の反復回数
	public let maxTokenRepetition: Int

	/// 確定範囲（Atomic・外部文法）の入れ子の深さ
	public let maxBoundaryDepth: Int

	/// 必須回数に届くまでに許す無消費の反復の回数
	public let maxEmptyRepetition: Int

	/// 一回の解析の総作業量。
	/// 項目とリンクとノードの追加、字句の照合、選択、木の具体化を数える。
	public let maxWork: Int

}
