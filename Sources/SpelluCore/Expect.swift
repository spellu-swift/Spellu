import SpelluLex


public enum Expect : Hashable, Sendable {

	/// 文字列リテラル
	case literal(String)
	/// 文字クラス
	case character(String)
	/// 特殊文字
	case special(String)
	/// 入力の終端
	case eos

}


extension Expect {

	/// 明示的なtriviaの読み取り。
	package static let trivia: Self = .special("TRIVIA")

}


extension Expect : CustomStringConvertible {
	
	public var description: String {
		switch self {
			case .literal(let string):
				string.wrapped(#"""#)
			case .character(let name):
				name.wrapped("[", "]")
			case .special(let name):
				name.uppercased().wrapped("@", "")
			case .eos:
				"$EOS"
		}
	}
	
}


extension Array where Element == Expect {

	/// caseの定義順、同じcaseでは引数の値順に並べる。eosは最後に置く。
	package var sorted: Self {
		func order(_ expect: Expect) -> (Int, String) {
			switch expect {
				case let .literal(value): (0, value)
				case let .character(value): (1, value)
				case let .special(value): (2, value)
				case .eos: (3, "")
			}
		}
		
		return sorted { order($0) < order($1) }
	}

}
