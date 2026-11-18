/// 字句照合の成功終了位置、または最遠失敗位置。いずれも原文上のIndex。
public enum TokenMatchResult : Equatable, Sendable {

	case success(String.Index)
	case failure(String.Index)

	/// 成功時の終了位置。不一致の場合はnil。
	package var matchedEnd: String.Index? {
		if case let .success(end) = self { end } else { nil }
	}

}
