import Basis
import UnicodeGeneralCategory
import UnicodeBinaryProperty


public enum CharacterPattern : Hashable, Sendable {
	
	case all
	case space
	case newline
	case any([UInt32])
	case range(ClosedRange<UInt32>)
	case general(UnicodeProperty.GeneralCategory)
	case binary(UnicodeProperty.BinaryProperty)
	case set(CharacterSet)
	
}


extension CharacterPattern {
	
	@inlinable
	public static func any(
		_ scalars: UnicodeScalar...,
	) -> Self {
		.any(scalars.map { $0.value })
	}

	@inlinable
	public static func any(
		_ scalars: [UnicodeScalar],
	) -> Self {
		.any(scalars.map { $0.value })
	}

	@inlinable
	public static func any(
		_ scalars: UInt32...,
	) -> Self {
		.any(scalars)
	}
	
	@inlinable
	public static func range(
		_ range: ClosedRange<UnicodeScalar>,
	) -> Self {
		.range(range.lowerBound.value...range.upperBound.value)
	}
	
}


extension CharacterPattern {
	
	public var asRangeSet: RangeSet<UInt32> {
		switch self {
			case .all:
				return .range(0...0x10FFFF)

			case .space:
				// TAB, Space_Separator(General Category)
				var ranges: RangeSet<UInt32> = .init()
				for scalar: UInt32 in [
					0x09, 0x20, 0xA0, 0x1680, 0x202F, 0x205F, 0x3000,
				] {
					ranges.insert(contentsOf: scalar..<(scalar + 1))
				}
				ranges.insert(contentsOf: 0x2000..<0x200B)
				return ranges

			case .newline:
				// LF, CR, Line_Separator(General Category), Paragraph_Separator(General Category)
				var ranges: RangeSet<UInt32> = .init()
				for scalar: UInt32 in [0x0A, 0x0D, 0x2028, 0x2029] {
					ranges.insert(contentsOf: scalar..<(scalar + 1))
				}
				return ranges

			case let .any(scalars):
				var ranges: RangeSet<UInt32> = .init()
				for scalar: UInt32 in scalars {
					ranges.insert(contentsOf: scalar..<(scalar + 1))
				}
				return ranges

			case let .range(range):
				return .range(range)

			case let .general(category):
				return category.rangeSet

			case let .binary(property):
				return property.rangeSet

			case let .set(set):
				return set.asRangeSet
		}
	}

}


extension RangeSet where Bound : BinaryInteger {
	
	@inlinable
	public static func range(
		_ range: ClosedRange<Bound>
	) -> Self {
		.init(range.lowerBound..<range.upperBound + 1)
	}
	
}
