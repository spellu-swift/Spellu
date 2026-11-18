
///
/// Token評価エンジン
///
public enum TokenEngine : Sendable {

	case interpreter

	/// Momojiriによる命令配列の評価。
	case momojiri

}
