

extension TokenIR {

	public var isNullable: Bool {
		amount.min == 0 || factor.isNullable
	}

}


extension TokenIR.Factor {

	public var isNullable: Bool {
		switch self {
			case .character: false
			case let .string(string): string.isEmpty
			case let .sequence(patterns): patterns.allSatisfy(\.isNullable)
			case let .alternative(patterns): patterns.contains(where: \.isNullable)
		}
	}

}
