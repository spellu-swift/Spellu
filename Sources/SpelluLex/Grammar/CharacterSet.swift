import Basis


@Default
public struct CharacterSet : Hashable, Sendable {

	public var categories: [CharacterPattern]

	public var inverted: Bool
	
}


extension CharacterSet {

	public static let empty: Self
	= .init(categories: [], inverted: false)

	public static func include(
		_ categories: CharacterPattern...,
	) -> Self {
		self.init(
			categories: categories,
			inverted: false
		)
	}
	
	public static func include(
		_ categories: [CharacterPattern],
	) -> Self {
		self.init(
			categories: categories,
			inverted: false
		)
	}
	
	public static func exclude(
		_ categories: CharacterPattern...,
	) -> Self {
		self.init(
			categories: categories,
			inverted: true
		)
	}
	
	public static func exclude(
		_ categories: [CharacterPattern],
	) -> Self {
		self.init(
			categories: categories,
			inverted: true
		)
	}
	
}


extension CharacterSet {
	
	public var asRangeSet: RangeSet<UInt32> {
		var ranges: RangeSet<UInt32> = .init()

		for category in categories {
			ranges.formUnion(category.asRangeSet)
		}

		if inverted {
			let all: CharacterPattern = .all
			ranges = all.asRangeSet.symmetricDifference(ranges)
		}

		return ranges
	}

}


