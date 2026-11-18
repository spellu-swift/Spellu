

///
/// Syntax Tree の構築戦略
///
public enum TreeStrategy : Sendable {
	
	/// 解析器が作った構造を忠実に保持
	case asis
	
	/// 内部的・匿名な構造を除去し、公開したい SyntaxTree に圧縮
	case compact
	
}


