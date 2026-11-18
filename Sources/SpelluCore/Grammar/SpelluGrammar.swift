

///
/// Spellu文法データ
///
public struct SpelluGrammar : Hashable, Sendable {
	
	public init(
		name: String,
		spaces: [SpacePattern],
		trivia: [String] = [],
		rules: [
			(
				name: String,
				label: Label,
				expose: Bool,
				syntax: Syntax,
			)
		],
	) {
		let rules: [SpelluRule]
		=
		Self.precompile(
			rules.map {
				SpelluRule(
					name: $0.name,
					label: $0.label,
					expose: $0.expose,
					syntax: $0.syntax,
				)
			}
		)
		
		self.name = name
		self.spaces = spaces
		self.trivia = trivia
		self.rules = rules
	}
	
	public let name: String
	public let spaces: [SpacePattern]
	public let trivia: [String] // ルール名
	public let rules: [SpelluRule]

	package var hasTrivia: Bool {
		!spaces.isEmpty || !trivia.isEmpty
	}

	@inlinable
	public func rule(
		for name: String,
	) -> SpelluRule? {
		rules.first{ $0.name == name }
	}

}

