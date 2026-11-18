import SpelluMacros


@Test("@Ruleの成功例")
func RuleMacro_1() {
	expect(
		macros: [
			"Rule": RuleMacro.self,
		],
		indentationWidth: .tab
	) {
"""
struct ExampleGrammar {
	@Rule
	let a = Rule {}
}
"""
	} expansion: {
"""
struct ExampleGrammar {
	let a = Rule {}

	var $a: RuleReference {
		Self.$a
	}

	static let $a: RuleReference = .init(grammar: id, rule: "a")
}
"""
	}
}


@Test("@Ruleはstaticなlet/varに適用できない")
func RuleMacro_Error_1() {
	expect(
		macros: [
			"Grammar": GrammarMacro.self,
			"Rule": RuleMacro.self,
		],
		diagnostics: [
			DiagnosticSpec(
				message: RuleMacroError.useStaticKeyword.rawValue,
				line: 2, column: 2,
				fixIts: [
					FixItSpec(message: RuleMacroFixIt.removeStaticKeyword.rawValue)
				]
			)
		],
		indentationWidth: .tab
	) {
"""
struct ExampleGrammar {
	@Rule
	static let foo = Rule {
	}
}
"""
	} expansion: {
"""
struct ExampleGrammar {
	static let foo = Rule {
	}
}
"""
	}
}


@Test("@Ruleはfuncに適用できない")
func RuleMacro_Error_2() {
	expect(
		macros: [
			"Grammar": GrammarMacro.self,
			"Rule": RuleMacro.self,
		],
		diagnostics: [
			DiagnosticSpec(
				message: RuleMacroError.mustVariable.rawValue,
				line: 2, column: 2
			)
		],
		indentationWidth: .tab
	) {
"""
struct ExampleGrammar {
	@Rule
	func foo() {}
}
"""
	} expansion: {
"""
struct ExampleGrammar {
	func foo() {}
}
"""
	}
}


