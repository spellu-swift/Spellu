import Basis
import SpelluLex


public enum SpelluError : ProgramError, Equatable, Sendable {

	// MARK: Grammar Error

	case noExposedRule(grammar: String)
	case precedenceOutOfRange(grammar: String, rule: String, precedence: Int)
	case invalidAmount(grammar: String, rule: String, amount: Amount)
	case emptyMatch(rule: String)
	case emptyString
	case unsupportedSyntax(grammar: String, rule: String, feature: String)

	// MARK: Runtime Error

	case duplicateGrammar(grammar: String)
	case duplicateRule(grammar: String, rule: String)
	case grammarNotFound(grammar: String)
	case ruleNotFound(grammar: String?, rule: String)
	case invalidStartOffset(Int)

	// MARK: Parse Error

	case unexpected(source: Source, offset: Int, line: Int, column: Int, expects: [Expect])
	case ambiguousPath(precedence: Int)
	case recursiveCall(grammar: String, rule: String, offset: Int)
	case safetyStop(SafetyReason)

	// MARK: Other Error

	case internalError(String)
		
}


public enum SafetyReason : Equatable, Sendable {
	
	case nonProgressingPath(limits: Int)
	case overLimitsOfRepetition(limits: Int)
	case overLimitsOfRecursion(limits: Int)
	case other(String)

}


extension SafetyReason : CustomStringConvertible {
	
	public var description: String {
		switch self {
			case let .nonProgressingPath(limits: limits):
				"Non Progressing Path: \(limits)"
			case let .overLimitsOfRepetition(limits: limits):
				"Over Limits of Repetition: \(limits)"
			case let .overLimitsOfRecursion(limits: limits):
				"Over Limits of Recursion: \(limits)"
			case let .other(reason):
				reason
		}
	}

}


