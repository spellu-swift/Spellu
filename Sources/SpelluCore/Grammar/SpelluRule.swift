

///
/// Spelluルール
///
public struct SpelluRule : Hashable, Sendable {
	
	public init(
		name: String,
		label: Label = .none,
		expose: Bool = false,
		syntax: Syntax,
	) {
		self.name = name
		self.label = label
		self.expose = expose
		self.syntax = syntax
	}
	
	public let name: String
	public let label: Label
	public let expose: Bool			// 文法の外部から呼び出せるか。
	public let syntax: Syntax

}


public struct Syntax : Hashable, Sendable {

	@inlinable
	public init(
		@SyntaxBuilder _ body: () -> [SyntaxIR],
	) {
		self.ir = body()
	}

	public let ir: [SyntaxIR]

}
