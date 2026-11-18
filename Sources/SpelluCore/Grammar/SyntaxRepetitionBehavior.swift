

/// Syntaxの反復動作。
public enum SyntaxRepetitionBehavior : Hashable, Sendable {

	/// 多い回数から試し、後続が失敗したら戻る。
	/// （積極的、『欲張り』）
	case eager

	/// 少ない回数から試し、後続の成立に必要なら増やす。
	/// （気が進まない、『渋々』）
	case reluctant

}
