import Basis
import BasisUtility
import SpelluLex


///
/// Spellu文法の中間表現
///
public indirect enum SyntaxIR : Hashable, Sendable {
	
	case token(
		_ label: Label,
		_ pattern: TokenIR,
		spacious: Bool,
		tag: String? = nil,
	)
	
	case word(
		_ label: Label,
		_ pattern: TokenIR,
		_ words: [String],
		caseInsensitive: Bool,
	)
	
	case trivia

	case optional(
		[SyntaxIR],
	)
	
	case sequence(
		_ label: Label,
		[SyntaxIR],
	)

	case atomic(
		[SyntaxIR],
	)
	
	case choiceOf(
		[SyntaxIR],
	)
	
	case anyOf(
		[Branch],
	)
	
	case `repeat`(
		_ value: [SyntaxIR],
		_ amount: Amount,
		behavior: SyntaxRepetitionBehavior = .eager,
	)
	
	case list(
		_ value: [SyntaxIR],
		_ separator: [SyntaxIR],
		lastSeparator: Acceptance,
		_ amount: Amount,
	)
	
	case enclosure(
		[SyntaxIR],
		amount: Amount,
		behavior: SyntaxRepetitionBehavior = .eager,
		opener: [SyntaxIR],
		closer: [SyntaxIR],
	)
	
	case ruleref(
		_ grammer: String?,
		_ rule: String,
	)
	
	case capture(
		[SyntaxIR]
	)

	case tokenref(
		tag: String,
		spacious: Bool,
	)
	
	case relabel(
		label: String,
		_ value: SyntaxIR,
	)

}


public enum Acceptance : Hashable, Sendable {

	case allow
	case deny

}


@Orderable
public struct Precedence : Hashable, Sendable {
	
	public init(rawValue: Int) {
		self.rawValue = rawValue
	}
	
	public let rawValue: Int
	
}


extension Precedence : ExpressibleByIntegerLiteral {
	
	@inlinable
	public init(integerLiteral value: IntegerLiteralType) {
		self.rawValue = value
	}

}


extension Precedence? {
	
	@inlinable
	public var rawValue: Int {
		self?.rawValue ?? Precedence.default.rawValue
	}
	
}


extension Precedence {

	public static let `default`: Self = .low

	public static let low: Self = .init(rawValue: 0)

	public static let middle: Self = .init(rawValue: 50)

	public static let high: Self = .init(rawValue: 100)

	public static let min: Self = .low

	public static let max: Self = .high

}


extension SyntaxIR {
	
	static func token(
		_ label: Label,
		_ pattern: [TokenIR],
		spacious: Bool = false,
		tag: String? = nil,
	) -> SyntaxIR {
		.token(
			label,
			wrap(pattern),
			spacious: spacious,
			tag: tag,
		)
	}

	static func word(
		_ label: Label,
		_ pattern: [TokenIR],
		_ words: [String],
		caseInsensitive: Bool,
	) -> SyntaxIR {
		.word(
			label,
			wrap(pattern),
			words,
			caseInsensitive: caseInsensitive,
		)
	}

	@inlinable
	static func wrap(
		_ pattern: [TokenIR]
	) -> TokenIR {
		if pattern.count == 1 {
			pattern[0]
		}
		else {
			.sequence(pattern)
		}
	}
	
}


extension SyntaxIR {

	@inlinable
	public func `as`(
		label: String,
	) -> SyntaxIR {
		switch self {
			case let .token(_, pattern, spacious, tag):
				.token(Label(label), pattern, spacious: spacious, tag: tag)
			case let .word(_, pattern, words, caseInsensitive):
				.word(Label(label), pattern, words, caseInsensitive: caseInsensitive)
			case let .sequence(_, body):
				.sequence(Label(label), body)
			case .ruleref:
				.relabel(label: label, self)
			default:
				.relabel(label: label, self)
		}
	}
	
}
