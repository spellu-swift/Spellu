

public struct Shebang {

	public init(
		source: SourceNode,
		command: String,
	) {
		self.source = source
		self.command = command
	}
	
	public var source: SourceNode
	public var command: String
	
}


extension Shebang {
	
	public static func parse(
		_ node: SourceNode,
	) throws -> Shebang {
		guard
			let command: SourceNode = node[at: 1]
		else { throw GeneralError.invalidFormat("missing at 1") }
		
		return .init(
			source: node,
			command: command.string
		)
	}
	
}
