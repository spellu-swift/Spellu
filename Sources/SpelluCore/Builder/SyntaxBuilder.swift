import Basis
import SpelluLex


@inlinable
public var Trivia: SyntaxIR {
	.trivia
}


public func Token(
	label: Label = .none,
	tag: String? = nil,
	@TokenBuilder _ body: () -> [TokenIR],
) -> SyntaxIR {
	.token(
		label,
		body(),
		spacious: true,
		tag: tag,
	)
}


public func Fragment(
	label: Label = .none,
	tag: String? = nil,
	@TokenBuilder _ body: () -> [TokenIR],
) -> SyntaxIR {
	.token(
		label,
		body(),
		spacious: false,
		tag: tag,
	)
}


public func Token(
	label: Label = .none,
	tag: String? = nil,
	_ string: String,
	ignoresCase: Bool? = nil,
) -> SyntaxIR {
	.token(
		label,
		[.string(string, caseInsensitive: ignoresCase)],
		spacious: true,
		tag: tag,
	)
}


public func Fragment(
	label: Label = .none,
	tag: String? = nil,
	_ string: String,
	ignoresCase: Bool? = nil,
) -> SyntaxIR {
	.token(
		label,
		[.string(string, caseInsensitive: ignoresCase)],
		spacious: false,
		tag: tag,
	)
}


@inlinable
public func Word(
	label: Label = .none,
	_ words: String...,
	caseInsensitive: Bool = false,
	@TokenBuilder _ rules: () -> [TokenIR],
) -> SyntaxIR {
	Word(
		label: label,
		words,
		caseInsensitive: caseInsensitive,
		rules,
	)
}


public func Word(
	label: Label = .none,
	_ words: [String],
	caseInsensitive: Bool = false,
	@TokenBuilder _ rules: () -> [TokenIR],
) -> SyntaxIR {
	.word(
		label,
		rules(),
		words,
		caseInsensitive: caseInsensitive,
	)
}


// MARK: Token Reference

@inlinable
public func Token(
	tag: String,
) -> SyntaxIR {
	.tokenref(
		tag: tag,
		spacious: true,
	)
}

@inlinable
public func Fragment(
	tag: String,
) -> SyntaxIR {
	.tokenref(
		tag: tag,
		spacious: false,
	)
}


// MARK: Rule

@inlinable
public func Rule(
	_ grammar: String,
	_ rule: String,
) -> SyntaxIR {
	.ruleref(
		grammar,
		rule,
	)
}


// MARK: Operator

@inlinable
public func Optional(
	_ body: SyntaxIR,
) -> SyntaxIR {
	.optional([body])
}


@inlinable
public func Optional(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SyntaxIR {
	.optional(body())
}


@inlinable
public func Sequence(
	label: Label = .none,
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SyntaxIR {
	.sequence(label, body())
}


@inlinable
public func Atomic(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SyntaxIR {
	.atomic(body())
}


/// 構文候補を記述順に試し、最初の成功で選択を確定する。
@inlinable
public func ChoiceOf(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SyntaxIR {
	.choiceOf(body())
}


@inlinable
public func Repeat(
	_ range: some RangeExpression<Int> = 0...,
	behavior: SyntaxRepetitionBehavior = .eager,
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SyntaxIR {
	.repeat(
		body(),
		range.asAmount,
		behavior: behavior,
	)
}


@inlinable
public func List(
	_ range: some RangeExpression<Int> = 0...,
	lastSeparator: Acceptance = .allow,
	@SyntaxBuilder value: () -> [SyntaxIR],
	@SyntaxBuilder separator: () -> [SyntaxIR],
) -> SyntaxIR {
	.list(
		value(),
		separator(),
		lastSeparator: lastSeparator,
		range.asAmount,
	)
}


@inlinable
public func Enclosure(
	_ opener: String,
	_ closer: String,
	_ range: some RangeExpression<Int> = 0...,
	behavior: SyntaxRepetitionBehavior = .reluctant,
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) -> SyntaxIR {
	.enclosure(
		body(),
		amount: range.asAmount,
		behavior: behavior,
		opener: [Token(label: "#opener", opener)],
		closer: [Token(label: "#closer", closer)],
	)
}


@inlinable
public func Enclosure(
	_ range: some RangeExpression<Int> = 0...,
	behavior: SyntaxRepetitionBehavior = .reluctant,
	@SyntaxBuilder _ body: () -> [SyntaxIR],
	@SyntaxBuilder opener: () -> [SyntaxIR],
	@SyntaxBuilder closer: () -> [SyntaxIR],
) -> SyntaxIR {
	.enclosure(
		body(),
		amount: range.asAmount,
		behavior: behavior,
		opener: opener(),
		closer: closer(),
	)
}


@inlinable
public func Capture(
	@SyntaxBuilder body: () -> [SyntaxIR],
) -> SyntaxIR {
	.capture(
		body(),
	)
}


extension SyntaxIR {
	
	public func precedence(
		_ precedence: Precedence,
	) -> Branch {
		.init(precedence: precedence, body: [self])
	}
	
}


@resultBuilder
public class SyntaxBuilder {
	
	// MARK: Expressions

	public static func buildExpression(
		_ rule: SyntaxIR,
	) -> SyntaxIR {
		rule
	}
	
	public static func buildExpression(
		_ rules: [SyntaxIR],
	) -> [SyntaxIR] {
		rules
	}
	
	// ex) Foo\.$rule
	public static func buildExpression(
		_ ref: RuleReference,
	) -> SyntaxIR {
		ref.ir
	}

	// ex) "spellu"
	public static func buildExpression(
		_ string: String,
	) -> SyntaxIR {
		.token(
			.none,
			[.string(string)],
			spacious: true,
		)
	}

	// MARK: Blocks

	public static func buildBlock(
	) -> [SyntaxIR] {
		[]
	}
	
	public static func buildPartialBlock(
		first: SyntaxIR,
	) -> [SyntaxIR] {
		[first]
	}
	
	public static func buildPartialBlock(
		first: [SyntaxIR],
	) -> [SyntaxIR] {
		first
	}
	
	public static func buildPartialBlock(
		accumulated: [SyntaxIR],
		next: SyntaxIR,
	) -> [SyntaxIR] {
		accumulated + [next]
	}
	
	public static func buildPartialBlock(
		accumulated: [SyntaxIR],
		next: [SyntaxIR],
	) -> [SyntaxIR] {
		accumulated + next
	}
	
	// MARK: if-else

	public static func buildOptional(
		_ component: [SyntaxIR]?,
	) -> [SyntaxIR] {
		component ?? []
	}

	public static func buildEither(
		first component: [SyntaxIR],
	) -> [SyntaxIR] {
		component
	}

	public static func buildEither(
		second component: [SyntaxIR],
	) -> [SyntaxIR] {
		component
	}

	// MARK: for-in

	public static func buildArray(
		_ components: [[SyntaxIR]],
	) -> [SyntaxIR] {
		components.flatMap{ $0 }
	}

}


