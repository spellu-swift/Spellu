//import Basis
//
//
//@inlinable
//public func Optional(
//	@TokenBuilder rules: () -> [TokenIR],
//) -> TokenIR {
//	.sequence(rules(), amount: .zeroOrOne)
//}
//
//
//@inlinable
//public func Sequence(
//	@TokenBuilder rules: () -> [TokenIR],
//) -> TokenIR {
//	.sequence(rules(), amount: .exactly(1))
//}
//
//
///// 字句候補を記述順に試し、同じ字句の後続失敗時には別候補へ戻る。
//@inlinable
//public func ChoiceOf(
//	@TokenBuilder rules: () -> [TokenIR],
//) -> TokenIR {
//	.alternative(rules())
//}
//
//
//@inlinable
//public func Repeat(
//	_ range: some RangeExpression<Int>,
//	behavior: TokenRepetitionBehavior = .eager,
//	@TokenBuilder rules: () -> [TokenIR],
//) -> TokenIR {
//	.sequence(rules(), amount: range.asAmount, behavior: behavior)
//}
//
//
//@inlinable
//public func Literal(
//	_ string: String,
//) -> TokenIR {
//	.string(string)
//}
//
//
//// MARK: .repeat()
//
//extension TokenIR {
//
//	@inlinable
//	public func `repeat`(
//		_ range: some RangeExpression<Int>,
//		behavior: TokenRepetitionBehavior = .eager,
//	) -> Self {
//		.init(
//			factor: self.factor,
//			amount: range.asAmount,
//			behavior: behavior,
//			caseInsensitive: self.caseInsensitive,
//		)
//	}
//	
//	@inlinable
//	public func ignoresCase(
//		_ flag: Bool = true,
//	) -> Self {
//		.init(
//			factor: factor,
//			amount: amount,
//			behavior: repetitionBehavior,
//			caseInsensitive: flag,
//		)
//	}
//	
//}
//
//
//extension CharacterClass {
//
//	@inlinable
//	public func `repeat`(
//		_ range: some RangeExpression<Int>,
//		behavior: TokenRepetitionBehavior = .eager,
//	) -> TokenIR {
//		.init(
//			factor: .character(self.set),
//			amount: range.asAmount,
//			behavior: behavior,
//		)
//	}
//
//	@inlinable
//	public func ignoresCase(
//		_ flag: Bool = true,
//	) -> TokenIR {
//		.init(
//			factor: .character(self.set),
//			amount: .exactly(1),
//			caseInsensitive: flag,
//		)
//	}
//
//}
//
//
//extension String {
//	
//	@inlinable
//	public func `repeat`(
//		_ range: some RangeExpression<Int>,
//		behavior: TokenRepetitionBehavior = .eager,
//	) -> TokenIR {
//		.init(
//			factor: .string(self),
//			amount: range.asAmount,
//			behavior: behavior,
//		)
//	}
//
//	@inlinable
//	public func ignoresCase(
//		_ flag: Bool = true,
//	) -> TokenIR {
//		.init(
//			factor: .string(self),
//			amount: .exactly(1),
//			caseInsensitive: flag,
//		)
//	}
//
//}
//
//
//
//@resultBuilder
//public class TokenBuilder {
//
//	// MARK: Expressions
//
//	public static func buildExpression(
//		_ rule: TokenIR,
//	) -> TokenIR {
//		rule
//	}
//
//	// ex) "spellu"
//	public static func buildExpression(
//		_ string: String,
//	) -> TokenIR {
//		.string(string)
//	}
//
//	public static func buildExpression(
//		_ rule: CharacterClass,
//	) -> TokenIR {
//		rule.asLexRule
//	}
//
//	// MARK: Blocks
//
//	public static func buildBlock(
//	) -> [TokenIR] {
//		[]
//	}
//
//	public static func buildPartialBlock(
//		first: TokenIR,
//	) -> [TokenIR] {
//		[first]
//	}
//	
//	public static func buildPartialBlock(
//		first: [TokenIR],
//	) -> [TokenIR] {
//		first
//	}
//	
//	public static func buildPartialBlock(
//		accumulated: [TokenIR],
//		next: TokenIR,
//	) -> [TokenIR] {
//		accumulated + [next]
//	}
//	
//	public static func buildPartialBlock(
//		accumulated: [TokenIR],
//		next: [TokenIR],
//	) -> [TokenIR] {
//		accumulated + next
//	}
//	
//	// MARK: if-else
//
//	public static func buildOptional(
//		_ component: [TokenIR]?,
//	) -> [TokenIR] {
//		component ?? []
//	}
//
//	public static func buildEither(
//		first component: [TokenIR],
//	) -> [TokenIR] {
//		component
//	}
//
//	public static func buildEither(
//		second component: [TokenIR],
//	) -> [TokenIR] {
//		component
//	}
//
//	// MARK: for-in
//
//	public static func buildArray(
//		_ components: [[TokenIR]],
//	) -> [TokenIR] {
//		components.flatMap{ $0 }
//	}
//
//}
//
