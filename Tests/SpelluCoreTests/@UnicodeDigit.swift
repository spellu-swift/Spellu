import SpelluCore


// 対象API: CharacterClass.digitとCharacter.digit。
// Swift Regex公開仕様のUnicode \d（Nd）、非十進数の除外、各範囲の境界、
// ASCII.digitとの違い、複数スカラーのCharacterを確認する。
// Swift 6.4の実機では\dが上付き数字・分数などにも一致したため、
// 除外条件は実機の\dではなく、公開仕様を明示する\p{Nd}と比較する。
// 仕様: swift-evolution/proposals/0363-unicode-for-string-processing.md#digits
struct UnicodeDigitTests {

	@Test(arguments: [
		"0", "9", "０", "９", "٠", "٩", "۰", "۹", "०", "९", "𝟎", "𝟡",
	])
	func 各言語の十進数字はSwiftRegexと同様に一致する(
		text: String,
	) throws {
		let regex: Regex<AnyRegexOutput>
		= try .init(#"\d"#).matchingSemantics(.unicodeScalar)
		let scalar: UnicodeScalar = try #require(text.unicodeScalars.first)
		#expect(text.wholeMatch(of: regex) != nil)
		#expect(CharacterClass.digit.matches(scalar: scalar))
		#expect(CharacterClass.digit.asRangeSet.contains(scalar.value))
		#expect(Character.digit.matches(scalar: scalar))
	}

	@Test(arguments: ["/", ":", "A", "²", "Ⅸ", "①", "½", "\u{301}"])
	func 十進数字以外は公開仕様のNdと同様に除外する(text: String) throws {
		let regex: Regex<AnyRegexOutput>
		= try .init(#"\p{Nd}"#).matchingSemantics(.unicodeScalar)
		let scalar: UnicodeScalar = try #require(text.unicodeScalars.first)
		#expect(text.wholeMatch(of: regex) == nil)
		#expect(!CharacterClass.digit.matches(scalar: scalar))
		#expect(!CharacterClass.digit.asRangeSet.contains(scalar.value))
		#expect(!Character.digit.matches(scalar: scalar))
	}

	@Test func 全数字範囲の両端を含み隣接する非数字を除外する() {
		let digits: CharacterClass = .digit
		for range: Range<UInt32> in digits.asRangeSet.ranges {
			for value: UInt32 in [range.lowerBound, range.upperBound - 1] {
				let scalar: UnicodeScalar = UnicodeScalar(value)!
				#expect(scalar.properties.numericType == .decimal)
				#expect(digits.matches(scalar: scalar))
			}
			for value: UInt32 in [range.lowerBound - 1, range.upperBound] {
				let scalar: UnicodeScalar = UnicodeScalar(value)!
				#expect(scalar.properties.numericType != .decimal)
				#expect(!digits.matches(scalar: scalar))
			}
		}
	}

	@Test func ASCIIの数字クラスは半角数字だけに限定する() {
		#expect(ASCII.digit.asRangeSet == RangeSet<UInt32>(0x30..<0x3A))
		for scalar: UnicodeScalar in ["0", "9"] {
			#expect(ASCII.digit.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in ["９", "٩", "९", "𝟡"] {
			#expect(CharacterClass.digit.matches(scalar: scalar))
			#expect(!ASCII.digit.matches(scalar: scalar))
		}
	}

	@Test(arguments: ["1\u{301}", "1️⃣"])
	func 複数スカラーの数字文字は公開仕様に従い除外する(
		text: String,
	) throws {
		let regex: Regex<AnyRegexOutput>
		= try .init(#"\p{Nd}"#).matchingSemantics(.unicodeScalar)
		let character: Character = try #require(text.first)
		#expect(text.count == 1)
		#expect(text.wholeMatch(of: regex) == nil)
		#expect(!CharacterClass.digit.matches(character))
		#expect(!Character.digit.matches(character))
	}

}
