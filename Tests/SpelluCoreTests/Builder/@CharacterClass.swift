import UnicodeBinaryProperty
import UnicodeGeneralCategory
import SpelluCore


struct CharacterClassTests {

	@Test func ASCII_anyはASCII範囲に一致する() {
		#expect(ASCII.any.matches(scalar: 0x00) == true)
		#expect(ASCII.any.matches(scalar: 0x7F) == true)
		#expect(ASCII.any.matches(scalar: 0x80) == false)
	}

	@Test func ASCII_spaceはタブと半角空白に一致する() {
		#expect(ASCII.space.matches(scalar: "\t") == true)
		#expect(ASCII.space.matches(scalar: " ") == true)
		#expect(ASCII.space.matches(scalar: "\n") == false)
	}

	@Test func ASCII_digitはASCII数字に一致する() {
		#expect(ASCII.digit.matches(scalar: "0") == true)
		#expect(ASCII.digit.matches(scalar: "9") == true)
		#expect(ASCII.digit.matches(scalar: "a") == false)
		#expect(ASCII.digit.matches(scalar: "９") == false)
	}

	@Test func ASCII_wordは英数字とアンダースコアに一致する() {
		#expect(ASCII.word.matches(scalar: "A") == true)
		#expect(ASCII.word.matches(scalar: "Z") == true)
		#expect(ASCII.word.matches(scalar: "a") == true)
		#expect(ASCII.word.matches(scalar: "z") == true)
		#expect(ASCII.word.matches(scalar: "5") == true)
		#expect(ASCII.word.matches(scalar: "_") == true)
		#expect(ASCII.word.matches(scalar: "é") == false)
		#expect(ASCII.word.matches(scalar: "-") == false)
	}

	@Test func CharacterClass_generalはUnicode一般カテゴリに一致する() {
		let control: CharacterClass
		= CharacterClass.general(.control)

		#expect(control.matches(scalar: 0x00) == true)
		#expect(control.matches(scalar: "A") == false)
	}

	@Test func CharacterClass_binaryはUnicode二値プロパティに一致する() {
		let identifierStart: CharacterClass
		= CharacterClass.binary(.xidStart)

		#expect(identifierStart.matches(scalar: "A") == true)
		#expect(identifierStart.matches(scalar: "5") == false)
	}

	@Test func CharacterClass_range() {
		#expect(CharacterClass.range("0"..."9").matches(scalar: "0") == true)
		#expect(CharacterClass.range(0x30...0x39).matches(scalar: "0") == true)
	}

	@Test func invertedは文字集合を反転する() {
		let vowels: CharacterClass
		= CharacterClass.any("aeiou")

		#expect(vowels.matches(scalar: "a") == true)
		#expect(vowels.matches(scalar: "b") == false)

		let nonVowels: CharacterClass
		= vowels.inverted

		#expect(nonVowels.matches(scalar: "a") == false)
		#expect(nonVowels.matches(scalar: "b") == true)
	}

	@Test func CharacterClass_rangeは整数Unicode範囲に一致する() {
		let uppercaseASCII: CharacterClass
		= .range(0x41...0x5A) // "A"..."Z"

		#expect(uppercaseASCII.matches(scalar: "A") == true)
		#expect(uppercaseASCII.matches(scalar: "Z") == true)
		#expect(uppercaseASCII.matches(scalar: "a") == false)
	}

	// MARK: Case Insensitive

	@Test func caseInsensitiveはASCII範囲で大文字小文字を区別しない() {
		let uppercaseASCII: CharacterClass
		= .range("A"..."Z")

		#expect(uppercaseASCII.matches(scalar: "A", caseInsensitive: true) == true)
		#expect(uppercaseASCII.matches(scalar: "Z", caseInsensitive: true) == true)
		#expect(uppercaseASCII.matches(scalar: "a", caseInsensitive: true) == true)
		#expect(uppercaseASCII.matches(scalar: "z", caseInsensitive: true) == true)
		#expect(uppercaseASCII.matches(scalar: "0", caseInsensitive: true) == false)
		#expect(uppercaseASCII.matches(scalar: "a") == false)
	}

	@Test func caseInsensitiveはCharacterとUnicodeScalarとIntの照合でSimpleCaseFoldingを適用する() {
		let sigma: CharacterClass
		= CharacterClass.any("Σ")

		#expect(sigma.matches("ς", caseInsensitive: true) == true)
		#expect(sigma.matches(scalar: "σ", caseInsensitive: true) == true)
		#expect(sigma.matches(scalar: 0x03C2, caseInsensitive: true) == true)
		#expect(sigma.matches("a", caseInsensitive: true) == false)
	}

	@Test func caseInsensitiveは各言語の代表的な文字の対応を照合する() {
		let microSign: CharacterClass
		= CharacterClass.any("µ")
		let longS: CharacterClass
		= CharacterClass.any("ſ")
		let kelvinSign: CharacterClass
		= CharacterClass.any("K")
		let ohmSign: CharacterClass
		= CharacterClass.any("Ω")
		let angstromSign: CharacterClass
		= CharacterClass.any("Å")

		// ギリシャ文字と互換記号
		#expect(microSign.matches("Μ", caseInsensitive: true) == true)
		#expect(kelvinSign.matches("k", caseInsensitive: true) == true)
		#expect(ohmSign.matches("ω", caseInsensitive: true) == true)
		#expect(angstromSign.matches("å", caseInsensitive: true) == true)
		#expect(longS.matches("S", caseInsensitive: true) == true)
	}

	@Test func caseInsensitiveはトルコ語の専用対応を既定の照合に使わない() {
		let latinI: CharacterClass
		= CharacterClass.any("I")
		let dottedCapitalI: CharacterClass
		= CharacterClass.any("İ")

		#expect(latinI.matches("i", caseInsensitive: true) == true)
		#expect(latinI.matches("ı", caseInsensitive: true) == false)
		#expect(dottedCapitalI.matches("i", caseInsensitive: true) == false)
	}

	@Test func caseInsensitiveはドイツ語のエスツェットに単純マッピングを適用する() {
		let sharpS: CharacterClass
		= CharacterClass.any("ß")

		#expect(sharpS.matches("ẞ", caseInsensitive: true) == true)
		#expect(sharpS.matches("s", caseInsensitive: true) == false)
	}

	@Test func caseInsensitiveはチェロキー文字と補助平面の文字を照合する() {
		let cherokee: CharacterClass
		= CharacterClass.any("Ꭰ")
		let deseret: CharacterClass
		= CharacterClass.any("𐐀")

		#expect(cherokee.matches("ꭰ", caseInsensitive: true) == true)
		#expect(deseret.matches("𐐨", caseInsensitive: true) == true)
	}

	@Test func caseInsensitiveはギリシャ語の複合文字の単純マッピングを照合する() {
		let greek: CharacterClass
		= CharacterClass.any("ᾈ")

		#expect(greek.matches("ᾀ", caseInsensitive: true) == true)
	}

}


// 対象API: CharacterClass.include(_:)、CharacterClass.exclude(_:)。
// 複数のCharacterClass、反転、入れ子、空引数とUnicode上限を確認する。
struct CharacterClassCompositionTests {

	@Test func includeは既存の文字クラスの和集合を作る() {
		let characters: CharacterClass = CharacterClass.include(
			ASCII.digit,
			CharacterClass.any("あ😀"),
			CharacterClass.range("a"..."c"),
		)
		for scalar: UnicodeScalar in ["0", "9", "あ", "😀", "a", "c"] {
			#expect(characters.matches(scalar: scalar))
			#expect(characters.asRangeSet.contains(scalar.value))
		}
		for scalar: UnicodeScalar in ["/", ":", "d", "A"] {
			#expect(!characters.matches(scalar: scalar))
			#expect(!characters.asRangeSet.contains(scalar.value))
		}
	}

	@Test func excludeは複数の文字クラスの和集合を反転する() {
		let characters: CharacterClass = CharacterClass.exclude(
			ASCII.digit,
			CharacterClass.newline,
		)
		for scalar: UnicodeScalar in ["0", "9", "\n", "\r", "\u{2028}"] {
			#expect(!characters.matches(scalar: scalar))
			#expect(!characters.asRangeSet.contains(scalar.value))
		}
		for scalar: UnicodeScalar in ["a", "あ", "\0", "\u{10FFFF}"] {
			#expect(characters.matches(scalar: scalar))
			#expect(characters.asRangeSet.contains(scalar.value))
		}
	}

	@Test func includeは引数の反転状態を保持する() {
		let characters: CharacterClass = CharacterClass.include(
			ASCII.digit.inverted,
			CharacterClass.any("5"),
		)
		#expect(characters.matches(scalar: "a"))
		#expect(characters.matches(scalar: "5"))
		#expect(!characters.matches(scalar: "4"))
		#expect(!characters.asRangeSet.contains(0x34))
	}

	@Test func excludeは入れ子と引数の反転状態を保持する() {
		let characters: CharacterClass = CharacterClass.exclude(
			CharacterClass.include(ASCII.digit.inverted),
			CharacterClass.any("5"),
		)
		#expect(characters.matches(scalar: "4"))
		#expect(characters.matches(scalar: "6"))
		#expect(!characters.matches(scalar: "5"))
		#expect(!characters.matches(scalar: "a"))
		#expect(characters.asRangeSet.contains(0x34))
		#expect(!characters.asRangeSet.contains(0x35))
	}

	@Test func 引数なしのincludeは空集合でexcludeは全体集合になる() {
		let included: CharacterClass = CharacterClass.include()
		let excluded: CharacterClass = CharacterClass.exclude()
		#expect(included.asRangeSet.isEmpty)
		#expect(excluded.asRangeSet == CharacterClass.all.asRangeSet)
		for scalar: UnicodeScalar in ["\0", "a", "\u{10FFFF}"] {
			#expect(!included.matches(scalar: scalar))
			#expect(excluded.matches(scalar: scalar))
		}
	}

}


// 対象API: CharacterClassの定義済みクラスと各構築オーバーロード。
struct CharacterClassConstructionTests {

	@Test func 定義済みクラスはそれぞれの文字範囲を返す() {
		#expect(CharacterClass.all.asRangeSet == RangeSet<UInt32>(0..<0x110000))
		#expect(CharacterClass.space.matches(scalar: "\t"))
		#expect(CharacterClass.space.matches(scalar: "\u{3000}"))
		#expect(!CharacterClass.space.matches(scalar: "\n"))
		#expect(CharacterClass.digit.asRangeSet
			== UnicodeProperty.GeneralCategory.decimalNumber.rangeSet)
		#expect(CharacterClass.digit.matches(scalar: "９"))
		for scalar: UnicodeScalar in ["あ", "\u{301}", "９", "_", "\u{200D}"] {
			#expect(CharacterClass.word.matches(scalar: scalar))
		}
		#expect(!CharacterClass.word.matches(scalar: "😀"))
	}

	@Test func anyの文字列版は結合文字と絵文字の全スカラーを含む() {
		let characters: CharacterClass = .any("e\u{301}👩‍💻e")
		#expect(characters.asRangeSet.ranges.flatMap { Array($0) }
			== [0x65, 0x301, 0x200D, 0x1F469, 0x1F4BB])
		#expect(!characters.matches(scalar: "é"))
		#expect(CharacterClass.any("").asRangeSet.isEmpty)
	}

	@Test func anyのスカラー版は可変長引数と配列を扱う() {
		let first: UnicodeScalar = "\0"
		let last: UnicodeScalar = "\u{10FFFF}"
		let variadic: CharacterClass = .any(first, last, first)
		let array: CharacterClass = .any([first, last, first])
		#expect(variadic.asRangeSet.ranges.flatMap { Array($0) }
			== [0, 0x10FFFF])
		#expect(array.asRangeSet == variadic.asRangeSet)
		#expect(!array.matches(scalar: "A"))
		#expect(CharacterClass.any().asRangeSet.isEmpty)
		#expect(CharacterClass.any([UnicodeScalar]()).asRangeSet.isEmpty)
	}

	@Test func rangeの両形式は閉区間の境界と単一文字を含む() {
		let lower: UnicodeScalar = "a"
		let upper: UnicodeScalar = "c"
		let scalarRange: CharacterClass = .range(lower...upper)
		let integerRange: CharacterClass = .range(0x61...0x63)
		#expect(scalarRange.asRangeSet == RangeSet<UInt32>(0x61..<0x64))
		#expect(integerRange.asRangeSet == scalarRange.asRangeSet)
		for characters: CharacterClass in [scalarRange, integerRange] {
			#expect(characters.matches(scalar: lower))
			#expect(characters.matches(scalar: upper))
			#expect(!characters.matches(scalar: "`"))
			#expect(!characters.matches(scalar: "d"))
		}
		let last: UnicodeScalar = "\u{10FFFF}"
		#expect(CharacterClass.range(last...last).asRangeSet
			== RangeSet<UInt32>(0x10FFFF..<0x110000))
		#expect(CharacterClass.range(0x10FFFF...0x10FFFF).asRangeSet
			== RangeSet<UInt32>(0x10FFFF..<0x110000))
	}

	@Test func includeの配列版は反転と重複と空配列を扱う() {
		let characters: CharacterClass = .include([
			.digit.inverted, .any("5"), .any("5"),
		])
		#expect(characters.matches(scalar: "A"))
		#expect(characters.matches(scalar: "5"))
		#expect(!characters.matches(scalar: "4"))
		#expect(CharacterClass.include([CharacterClass]()).asRangeSet.isEmpty)
	}

	@Test func excludeの配列版は入れ子と空配列を扱う() {
		let characters: CharacterClass = .exclude([
			.include([.digit.inverted]), .any("5"),
		])
		#expect(characters.matches(scalar: "4"))
		#expect(!characters.matches(scalar: "5"))
		#expect(!characters.matches(scalar: "A"))
		#expect(CharacterClass.exclude([CharacterClass]()).asRangeSet
			== CharacterClass.all.asRangeSet)
	}

}
