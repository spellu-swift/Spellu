import SpelluLex


///
/// 空白パターン
///
public enum SpacePattern : Hashable, Sendable {
	
	case space
	case newline
	case character(CharacterClass)
	case string(String)
	case token(TokenIR)
	
}

