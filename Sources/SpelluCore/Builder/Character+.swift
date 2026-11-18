import Basis
import UnicodeBinaryProperty
import UnicodeGeneralCategory
import SpelluLex


public enum ASCII {}


extension ASCII {
	
	// (?:.)
	@inlinable
	public static var any: CharacterClass {
		.init(set: .include(.range(0x00...0x7F)))
	}

	// \s から 改行を除外したもの
	@inlinable
	public static var space: CharacterClass {
		.init(set: .include(.any(["\t", "\u{000B}", "\u{000C}", " "])))
	}
	
	// \d
	@inlinable
	public static var digit: CharacterClass {
		.init(set: .include(.range("0"..."9")))
	}
	
	// \w
	@inlinable
	public static var word: CharacterClass {
		.init(set: .include(
			.range("0"..."9"),
			.range("a"..."z"),
			.range("A"..."Z"),
			.any("_"),
		))
	}
	
	// \R
	@inlinable
	public static var newline: CharacterClass {
		.init(set: .include(.newline))
	}
	
	// \R
	@inlinable
	public static var notNewline: CharacterClass {
		.init(set: .exclude(.newline))
	}
	
	// [...]
	@inlinable
	public static func any(
		_ pattern: CharacterPattern...,
	) -> CharacterClass {
		.init(set: .include(pattern))
	}
	
}


// MARK: Pre-defined Character sets

extension Character {
	
	// (?:.)
	@inlinable
	public static var all: CharacterClass {
		.all
	}
	
	// \s
	@inlinable
	public static var space: CharacterClass {
		.space
	}
	
	// ^\R
	@inlinable
	public static var newline: CharacterClass {
		.newline
	}
	
	// \R
	@inlinable
	public static var notNewline: CharacterClass {
		.notNewline
	}
	
	// \d
	@inlinable
	public static var digit: CharacterClass {
		.digit
	}
	
	// \w
	@inlinable
	public static var word: CharacterClass {
		.word
	}
	
	// Unicode General Category
	@inlinable
	public static func general(
		_ category: UnicodeProperty.GeneralCategory,
	) -> CharacterClass {
		.general(category)
	}
	
	// Unicode Binary Property
	@inlinable
	public static func binary(
		_ property: UnicodeProperty.BinaryProperty,
	) -> CharacterClass {
		.binary(property)
	}

	// [abc]
	@inlinable
	public static func any(
		_ characters: String,
	) -> CharacterClass {
		.any(characters)
	}

	// [abc]
	@inlinable
	public static func any(
		_ scalars: UnicodeScalar...,
	) -> CharacterClass {
		.any(scalars)
	}

	// [abc]
	@inlinable
	public static func any(
		_ scalars: [UnicodeScalar],
	) -> CharacterClass {
		.any(scalars)
	}
	
	// [A-Z]
	@inlinable
	public static func range(
		_ range: ClosedRange<UnicodeScalar>,
	) -> CharacterClass {
		.range(range)
	}

	// [A-Z]
	@inlinable
	public static func range(
		_ range: ClosedRange<UInt32>,
	) -> CharacterClass {
		.range(range)
	}

	// [...]
	@inlinable
	public static func include(
		_ patterns: CharacterClass...,
	) -> CharacterClass {
		.include(patterns)
	}
	
	// [...]
	@inlinable
	public static func include(
		_ patterns: [CharacterClass],
	) -> CharacterClass {
		.include(patterns)
	}

	// [^...]
	@inlinable
	public static func exclude(
		_ patterns: CharacterClass...,
	) -> CharacterClass {
		.exclude(patterns)
	}
	
	// [^...]
	@inlinable
	public static func exclude(
		_ patterns: [CharacterClass],
	) -> CharacterClass {
		.exclude(patterns)
	}

}


