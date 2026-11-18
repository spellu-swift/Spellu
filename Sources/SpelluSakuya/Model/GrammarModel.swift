import Basis
import SpelluCore
import SpelluLex

struct GrammarID: Hashable, Sendable { let index: Int }
struct RuleID: Hashable, Sendable { let index: Int }
struct ExprID: Hashable, Sendable { let index: Int }
struct ScopeID: Hashable, Sendable { let index: Int }
struct AtomID: Hashable, Sendable { let index: Int }
struct LexemeID: Hashable, Sendable { let index: Int }
struct ProgramID: Hashable, Sendable { let index: Int }


/// 入力に依存しない、名前解決済みのSakuya専用モデル。
struct GrammarModel: Sendable {

	struct Grammar: Sendable {
		let name: String
		let rules: [String: RuleID]
		let entry: RuleID?
		let trivia: TriviaPlan
	}

	struct Rule: Sendable {
		let grammar: GrammarID
		let name: String
		let label: Label
		let exposed: Bool
		let scope: ScopeID
		let body: ExprID
	}

	struct Expression: Sendable {
		let grammar: GrammarID
		let kind: Kind
	}

	enum Kind: Sendable {
		case empty
		case point(AtomID)
		case fail
		case sequence([ExprID])
		case group(ExprID, ScopeID, Label)
		case choice([Branch])
		case optional(ExprID, ScopeID, ScopeID)
		case repetition(LoopPlan)
		case list(ListPlan)
		case lexical(LexemeID)
		case reference(RuleID)
		case tokenReference(String, Bool, AtomID)
		case capture(ExprID)
		case atomic(ExprID, ScopeID, probe: Bool)
		case relabel(ExprID, Label)
		case trivia
		case eos
	}

	struct Branch: Sendable {
		let body: ExprID
		let rank: Int
	}

	struct LoopPlan: Sendable {
		let body: ExprID
		let minimum: Int
		let maximum: Int?
		let behavior: SyntaxRepetitionBehavior
		let scope: ScopeID
		let bodyScope: ScopeID
		let control: ScopeID
	}

	struct ListPlan: Sendable {
		let body: ExprID
		let separator: ExprID
		let rest: ExprID
		let minimum: Int
		let maximum: Int?
		let trailing: Acceptance
		let scope: ScopeID
	}

	struct TriviaPlan: Sendable {
		let optional: ProgramID
		let required: ProgramID
		let hasLexical: Bool
		let syntax: [ExprID]
	}

	struct Lexeme: Sendable {
		let program: ProgramID
		let pattern: TokenIR
		let label: Label
		let spacious: Bool
		let tag: String?
		let words: [String]?
		let insensitive: Bool
		let atom: AtomID
	}

	enum Atom: Hashable {
		case lexical(PatternKey, Bool, [String]?, Bool)
		case position(ScopeID)
		case reference(GrammarID, String, Bool)
	}

	let grammars: [Grammar]
	let rules: [Rule]
	let expressions: [Expression]
	let lexemes: [Lexeme]
	let programs: [TokenProgram]
	let grammarNames: [String: GrammarID]

	func start(_ reference: RuleReference?) throws -> RuleID {
		guard let first: Grammar = grammars.first else {
			throw SpelluError.grammarNotFound(grammar: reference?.grammar ?? "")
		}
		let name: String = reference?.grammar ?? first.name
		guard let owner: GrammarID = grammarNames[name] else {
			throw SpelluError.grammarNotFound(grammar: name)
		}
		let grammar: Grammar = grammars[owner.index]
		if let reference {
			guard let rule: RuleID = grammar.rules[reference.rule] else {
				throw SpelluError.ruleNotFound(
					grammar: name,
					rule: reference.rule
				)
			}
			return rule
		}
		guard let entry: RuleID = grammar.entry else {
			throw SpelluError.noExposedRule(grammar: name)
		}
		return entry
	}

}
