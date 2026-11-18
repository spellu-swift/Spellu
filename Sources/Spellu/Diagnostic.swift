

public struct Diagnostic : Error, Sendable {
	
	public init(
		node: SourceNode,
		message: some DiagnosticMessage,
	) {
		self.node = node
		self.severity = message.severity
		self.messageID = message.messageID
		self.message = message.message
	}
	
	public let node: SourceNode
	public let severity: Severity
	public let messageID: String
	public let message: String
	
}


extension Diagnostic : CustomStringConvertible {
	
	public var description: String {
		"##(\(node.begin):\(node.end)): Error: \(message)"
	}
	
}


public protocol DiagnosticMessage {

	var severity: Severity { get }
	var messageID: String { get }
	var message: String { get }
	
}


public enum Severity : Sendable {
	
	case error
	case warning
	
}


public protocol DiagnosticErrorMessage : DiagnosticMessage {
}


extension DiagnosticErrorMessage {
	
	public var severity: Severity { .error }
	
}


extension DiagnosticErrorMessage where Self : RawRepresentable<String> {
	
	public var messageID: String { "\(type(of: self)).\(self)" }
	public var message: String { rawValue }
	
}


public protocol DiagnosticNotifier {

	mutating func notify(
		_ diagnostic: Diagnostic,
	) -> Void
	
}


public struct DiagnosticContainer : DiagnosticNotifier {
	
	public init(
	) {
		self.diagnostics = []
	}

	public mutating func notify(
		_ diagnostic: Diagnostic,
	) {
		self.diagnostics.append(diagnostic)
	}
	
	public internal(set) var diagnostics: [Diagnostic]
	
	public var warnings: [Diagnostic] {
		diagnostics.filter {
			$0.severity == .warning
		}
	}
	
	public var errors: [Diagnostic] {
		diagnostics.filter {
			$0.severity == .error
		}
	}
	
}
