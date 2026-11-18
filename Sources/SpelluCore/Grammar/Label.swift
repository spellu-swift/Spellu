

///
/// ラベル
///
public enum Label : Hashable, Sendable {
	
	case none
	case labeled(String)
	
}


extension Label {

	@inlinable
	public init(
		_ string: String?,
	) {
		if let string {
			self = .labeled(string)
		}
		else {
			self = .none
		}
	}

	@inlinable
	public var string: String? {
		switch self {
		case .none:
			nil
		case .labeled(let string):
			string
		}
	}
	
	@inlinable
	public var isTemporary: Bool {
		switch self {
		case .none:
			true
		case .labeled(let string):
			string.hasPrefix("#")// || string.hasPrefix("$")
		}
	}
	
	@inlinable
	public func map(
		_ transform: (String) -> String,
	) -> Self {
		switch self {
		case .none:
			.none
		case .labeled(let string):
			.labeled(transform(string))
		}
	}

	@inlinable
	public func ensure(
		_ string: String,
	) -> Self {
		switch self {
		case .none:
			.labeled(string)
		case .labeled:
			self
		}
	}

}


extension Label : ExpressibleByStringLiteral {

	@inlinable
	public init(
		stringLiteral value: String,
	) {
		self = .labeled(value)
	}

}


extension Label : CustomStringConvertible {
	
	public var description: String {
		switch self {
		case .none:
			"<>"
		case .labeled(let string):
			"<\(string)>"
		}
	}

}
