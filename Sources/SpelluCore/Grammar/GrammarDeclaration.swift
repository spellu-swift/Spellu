

///
/// Spell文法定義
///
public protocol GrammarDeclaration : Sendable {
	
	static var `default`: Self { get }

	static var id: String { get }
	
	func grammar(
	) -> SpelluGrammar
	
}


