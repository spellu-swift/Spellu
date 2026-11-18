

public enum SourceIndentation : Sendable {
	
	case space(_ count: Int)
	case tab(_ count: Int)
	case custom(String)
	
	public var string: String {
		switch self {
			case .space(let count):
				String(repeating: " ", count: count)
			case .tab(let count):
				String(repeating: "\t", count: count)
			case .custom(let string):
				string
		}
	}
	
	public func string(
		repeat times: Int = 1
	) -> String {
		switch self {
			case .space(let count):
				String(repeating: " ", count: count * times)
			case .tab(let count):
				String(repeating: "\t", count: count * times)
			case .custom(let string):
				String(repeating: string, count: times)
		}
	}
	
}


public final class SourceWriter {
	
	public init(
		indentation: SourceIndentation = .tab(1),
		newline: String = "\n",
	) {
		self.indentation = indentation
		self.newline = newline
		self.indentLevel = 0
		self.result = ""
	}
	
	public let indentation: SourceIndentation
	public let newline: String
	var indentLevel: Int
	public internal(set) var result: String
	
	public func indent(
		_ count: Int = 1,
		perform: () -> Void,
	) {
		self.indentLevel += count

		perform()

		self.indentLevel -= count
	}
	
	@inlinable
	public func write(
		_ strings: (any StringProtocol)...,
	) {
		write(strings)
	}
		
	public func write(
		_ strings: [any StringProtocol],
	) {
		for string in strings {
			self.result += string
		}
	}
	
	public func write(
		space count: Int,
	) {
		self.result += String(repeating: " ", count: count)
	}
	
	public func writeIndent(
	) {
		write(indentation.string(repeat: indentLevel))
	}
	
	public func writeLine(
		_ strings: (any StringProtocol)...,
	) {
		writeIndent()

		write(strings)
		
		write(newline)
	}
	
	public func writeLine(
		perform: () -> Void,
	) {
		write(indentation.string(repeat: indentLevel))
		
		perform()
		
		write(newline)
	}
	
}
