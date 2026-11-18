import UnicodeBinaryProperty
import UnicodeGeneralCategory
@testable import SpelluLex


// 対象API: CharacterPattern.asRangeSet。
// 全カテゴリ、空集合、範囲の両端、Unicode上限、入れ子と反転を確認する。
struct CharacterPatternRangeSetTests {

	@Test func allはUnicode範囲の両端を含む() {
		let ranges: RangeSet<UInt32> = CharacterPattern.all.asRangeSet
		#expect(ranges == RangeSet<UInt32>(0..<0x110000))
		#expect(ranges.contains(0))
		#expect(ranges.contains(0x10FFFF))
		#expect(!ranges.contains(0x110000))
	}

	@Test func spaceは水平空白18文字に一致する() {
		let ranges: RangeSet<UInt32> = CharacterPattern.space.asRangeSet
		let expected: [UInt32] = [
			0x09, 0x20, 0xA0, 0x1680,
			0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
			0x2006, 0x2007, 0x2008, 0x2009, 0x200A,
			0x202F, 0x205F, 0x3000,
		]
		#expect(ranges.ranges.flatMap { Array($0) } == expected)
		for scalar: UInt32 in [0x0A, 0x0D, 0x85, 0x200B, 0x2028, 0x2029] {
			#expect(!ranges.contains(scalar))
		}
	}

	@Test func newlineはLFとCRと行段落区切りだけを含む() {
		let ranges: RangeSet<UInt32>
		= CharacterPattern.newline.asRangeSet
		#expect(ranges.ranges.flatMap { Array($0) }
			== [0x0A, 0x0D, 0x2028, 0x2029])
		for scalar: UInt32 in [0x09, 0x0B, 0x0C, 0x20, 0x85, 0x2027, 0x202A] {
			#expect(!ranges.contains(scalar))
		}
	}

	@Test func anyは空集合と重複と補助平面に対応する() {
		#expect(CharacterPattern.any([UInt32]()).asRangeSet.isEmpty)
		let ranges: RangeSet<UInt32>
		= CharacterPattern.any([0, 0x41, 0x41, 0x1F600,
			0x10FFFF]).asRangeSet
		#expect(ranges.ranges.flatMap { Array($0) }
			== [0, 0x41, 0x1F600, 0x10FFFF])
		#expect(!ranges.contains(0x42))
	}

	@Test func rangeは閉区間の両端と単一文字とUnicode上限を含む() {
		let ranges: RangeSet<UInt32>
		= CharacterPattern.range(0x41...0x5A).asRangeSet
		#expect(ranges == RangeSet<UInt32>(0x41..<0x5B))
		#expect(!ranges.contains(0x40))
		#expect(ranges.contains(0x5A))
		#expect(!ranges.contains(0x5B))
		#expect(CharacterPattern.range(0x10FFFF...0x10FFFF)
			.asRangeSet == RangeSet<UInt32>(0x10FFFF..<0x110000))
	}

	@Test func generalは全一般カテゴリのUnicode範囲を返す() {
		for category: UnicodeProperty.GeneralCategory in
			UnicodeProperty.GeneralCategory.allCases {
			#expect(CharacterPattern.general(category).asRangeSet
				== category.rangeSet)
		}
		let controls: RangeSet<UInt32>
		= CharacterPattern.general(.control).asRangeSet
		#expect(controls.contains(0))
		#expect(!controls.contains(0x41))
	}

	@Test func binaryは全二値プロパティのUnicode範囲を返す() {
		for property: UnicodeProperty.BinaryProperty in
			UnicodeProperty.BinaryProperty.allCases {
			#expect(CharacterPattern.binary(property).asRangeSet
				== property.rangeSet)
		}
		let starts: RangeSet<UInt32>
		= CharacterPattern.binary(.xidStart).asRangeSet
		#expect(starts.contains(0x41))
		#expect(!starts.contains(0x35))
	}

	@Test func setは入れ子の和集合と反転を計算する() {
		let category: CharacterPattern = .set(.include(
			.range(0x41...0x43),
			.set(.include(.any([0x43, 0x1F600]))),
		))
		#expect(category.asRangeSet.ranges.flatMap { Array($0) }
			== [0x41, 0x42, 0x43, 0x1F600])

		let inverted: RangeSet<UInt32>
		= CharacterPattern.set(.exclude(category)).asRangeSet
		#expect(inverted.contains(0))
		#expect(!inverted.contains(0x41))
		#expect(!inverted.contains(0x1F600))
		#expect(inverted.contains(0x10FFFF))
		#expect(!inverted.contains(0x110000))
		#expect(CharacterPattern.set(.exclude(.set(.exclude(category))))
			.asRangeSet == category.asRangeSet)
	}

	@Test func 空集合と全体集合の反転を計算する() {
		#expect(CharacterPattern.set(.include([])).asRangeSet.isEmpty)
		#expect(CharacterPattern.set(.exclude([])).asRangeSet
			== CharacterPattern.all.asRangeSet)
		#expect(CharacterPattern.set(.exclude(.all)).asRangeSet.isEmpty)
	}

}
