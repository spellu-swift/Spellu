///
/// Mikazuchiの安全上限
///
/// 上限を超えた解析は `SpelluError.safetyStop` で止まり、途中の候補を成功として返さない。
///
public struct Limits : Equatable, Sendable {

	public static let `default`: Self = .init()

	/// 省略した上限は既定値になる。負の値は0として扱う。
	public init(
	) {
	}

}
