

/// Spellu文法定義マクロ (Extension)
@attached(
	extension,
	names: arbitrary,
	conformances: GrammarDeclaration
)
public macro Grammar(
	spaces: [SpacePattern],
)
= #externalMacro(module: "SpelluMacros", type: "GrammarMacro")


/// Spelluルールマクロ (Extension)
/// Spellu文法（@Grammarでマークした）の中で使用します。
/// @Ruleでマークしたvar変数は、他のルールから`FooGrammar$<rule>`で参照できます。
/// publicなルールは、文法の外部から呼び出せるルールとして登録されます。
@attached(
	peer,
	names: prefixed(`$`)
)
public macro Rule(
	label: Label = .none,
	trivia: Bool = false,
)
= #externalMacro(module: "SpelluMacros", type: "RuleMacro")


