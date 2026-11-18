import SpelluCore
import SpelluInterpreter
import SpelluSakuya
import SpelluHoori


extension Spellu {
	
	public enum Engine : Sendable {

		/// SyntaxIRを直接評価する構文解析器
		case interpreter(
			limits: SpelluInterpreter.Limits = .default,
		)
		
		/// 継続ベースの構文解析器
		///　Continuation-Based Generalized Parser
		case sakuya(
			limits: SpelluSakuya.SafetyLimits = .default,
		)
		
		/// Earley法をベースとした構文解析器
		case hoori(
			limits: SpelluHoori.HooriLimits = .default,
		)
		
	}
	

}


extension Spellu.Engine {

	/// 標準オプションのInterpreter
	public static var interpreter: Self { .interpreter(limits: .default) }
	
	/// 標準オプションのSakuya
	public static var sakuya: Self { .sakuya(limits: .default) }

	/// 標準オプションのHoori
	public static var hoori: Self { .hoori(limits: .default) }

}


extension Spellu.Engine : CustomStringConvertible {
	
	public var description: String {
		switch self {
			case .interpreter:
				"Interpreter"
			case .sakuya:
				"Sakuya"
			case .hoori:
				"Hoori"
		}
	}
	
}
