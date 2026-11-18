import Basis
import UnicodeGeneralCategory
import UnicodeBinaryProperty
import SpelluLex


///
/// 文字クラス
///
public struct CharacterClass : Hashable, Sendable {

	@inlinable
	init(set: CharacterSet) {
		self.set = set
	}

	@usableFromInline
	package var set: CharacterSet

}


extension CharacterClass {
	
	@inlinable
	public var asRangeSet: RangeSet<UInt32> {
		self.set.asRangeSet
	}

}


extension CharacterClass {
	
	public static let empty: CharacterClass
	= .init(set: .empty)
	
	// (?:.)
	@inlinable
	public static var all: CharacterClass {
		.init(set: .include(.all))
	}

	// \s exclude Line Separator
	@inlinable
	public static var space: CharacterClass {
		.init(set: .include(.space))
	}
	
	// ^\R
	@inlinable
	public static var newline: CharacterClass {
		.init(set: .include(.newline))
	}
	
	// \R
	@inlinable
	public static var notNewline: CharacterClass {
		.init(set: .exclude(.newline))
	}
	
	// \d: Decimal_Number（Nd）
	@inlinable
	public static var digit: CharacterClass {
		.general(.decimalNumber)
	}
	
	// \w
	@inlinable
	public static var word: CharacterClass {
		.init(set: .include(
			.binary(.alphabetic),
			.general(.mark),
			.general(.decimalNumber),
			.general(.connectorPunctuation),
			.binary(.joinControl),
		))
	}

	// Unicode General Category
	@inlinable
	public static func general(
		_ category: UnicodeProperty.GeneralCategory,
	) -> CharacterClass {
		.init(set: .include(.general(category)))
	}
	
	// Unicode Binary Property
	@inlinable
	public static func binary(
		_ property: UnicodeProperty.BinaryProperty,
	) -> CharacterClass {
		.init(set: .include(.binary(property)))
	}

	// [abc]
	@inlinable
	public static func any(
		_ characters: String,
	) -> CharacterClass {
		.any(characters.unicodeScalars.asArray)
	}

	// [abc]
	@inlinable
	public static func any(
		_ scalars: UnicodeScalar...,
	) -> CharacterClass {
		.init(set: .include(.any(scalars.map(\.value))))
	}

	// [abc]
	@inlinable
	public static func any(
		_ scalars: [UnicodeScalar],
	) -> CharacterClass {
		.init(set: .include(.any(scalars.map(\.value))))
	}
	
	// [A-Z]
	@inlinable
	public static func range(
		_ range: ClosedRange<UnicodeScalar>,
	) -> CharacterClass {
		.init(set: .include(.range(range)))
	}

	// [A-Z]
	@inlinable
	public static func range(
		_ range: ClosedRange<UInt32>,
	) -> CharacterClass {
		.init(set: .include(.range(range)))
	}

	// [...]
	@inlinable
	public static func include(
		_ patterns: CharacterClass...,
	) -> CharacterClass {
		.init(set: .include(patterns.map { .set($0.set) }))
	}
	
	// [...]
	@inlinable
	public static func include(
		_ patterns: [CharacterClass],
	) -> CharacterClass {
		.init(set: .include(patterns.map { .set($0.set) }))
	}
	
	// [^...]
	@inlinable
	public static func exclude(
		_ patterns: CharacterClass...,
	) -> CharacterClass {
		.init(set: .exclude(patterns.map { .set($0.set) }))
	}
	
	// [^...]
	@inlinable
	public static func exclude(
		_ patterns: [CharacterClass],
	) -> CharacterClass {
		.init(set: .exclude(patterns.map { .set($0.set) }))
	}
	
}


// MARK: Manipulations

extension CharacterClass {
	
	/// 文字セットを反転
	public var inverted: Self {
		var set = self.set
		set.inverted.toggle()
		return Self(set: set)
	}
	
	@inlinable
	public var asLexRule: TokenIR {
		.init(factor: .character(set), amount: .exactly(1))
	}
	
}
