import SpelluCore


// 対象API: extension Characterの全公開構築API。
// all/space/digit/word/newline/notNewline、general/binary、anyの3形式、
// rangeの2形式、include/excludeの可変長引数と配列を確認する。
// 正常系と非対象文字、空入力、重複、結合文字、範囲の両端を対象にする。
struct CharacterConstructionTests {

	@Test func allはNULからUnicode上限までを含む() {
		let characters: CharacterClass = Character.all
		#expect(characters.asRangeSet == RangeSet<UInt32>(0..<0x110000))
		for scalar: UnicodeScalar in ["\0", "A", "あ", "😀", "\u{10FFFF}"] {
			#expect(characters.matches(scalar: scalar))
		}
		#expect(!characters.asRangeSet.contains(0x110000))
	}

	@Test func spaceはUnicode水平空白を含み改行を含まない() {
		let characters: CharacterClass = Character.space
		for scalar: UnicodeScalar in [
			"\t", " ", "\u{A0}", "\u{1680}", "\u{2000}", "\u{200A}",
			"\u{202F}", "\u{205F}", "\u{3000}",
		] {
			#expect(characters.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in [
			"\n", "\r", "\u{B}", "\u{C}", "\u{85}", "\u{200B}",
			"\u{2028}", "\u{2029}", "A",
		] {
			#expect(!characters.matches(scalar: scalar))
		}
	}

	@Test func digitはUnicode十進数字に一致する() {
		let characters: CharacterClass = Character.digit
		#expect(characters.asRangeSet
			== UnicodeProperty.GeneralCategory.decimalNumber.rangeSet)
		for scalar: UnicodeScalar in ["0", "9", "９", "\u{660}", "\u{96F}", "𝟠"] {
			#expect(characters.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in ["/", ":", "²", "Ⅸ", "①", "A"] {
			#expect(!characters.matches(scalar: scalar))
		}
	}

	@Test func wordはUnicodeの文字と数字と結合文字と接続文字を含む() {
		let characters: CharacterClass = Character.word
		for scalar: UnicodeScalar in [
			"A", "é", "あ", "0", "９", "\u{301}", "_", "\u{203F}",
			"\u{200C}", "\u{200D}",
		] {
			#expect(characters.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in [" ", "\n", "-", "😀"] {
			#expect(!characters.matches(scalar: scalar))
		}
	}

	@Test func newlineはLFとCRと行段落区切りを含む() {
		let characters: CharacterClass = Character.newline
		#expect(characters.asRangeSet.ranges.flatMap { Array($0) }
			== [0xA, 0xD, 0x2028, 0x2029])
		for scalar: UnicodeScalar in ["\n", "\r", "\u{2028}", "\u{2029}"] {
			#expect(characters.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in ["\t", "\u{B}", "\u{C}", "\u{85}", "A"] {
			#expect(!characters.matches(scalar: scalar))
		}
	}

	@Test func notNewlineは改行以外をUnicode範囲内で含む() {
		let characters: CharacterClass = Character.notNewline
		#expect(characters.asRangeSet.intersection(
			Character.newline.asRangeSet,
		).isEmpty)
		#expect(characters.asRangeSet.union(Character.newline.asRangeSet)
			== Character.all.asRangeSet)
		for scalar: UnicodeScalar in ["\0", "あ", "\u{10FFFF}"] {
			#expect(characters.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in ["\n", "\r", "\u{2028}", "\u{2029}"] {
			#expect(!characters.matches(scalar: scalar))
		}
	}

	@Test func generalは指定した一般カテゴリの文字を選ぶ() {
		let characters: CharacterClass = Character.general(.uppercaseLetter)
		for scalar: UnicodeScalar in ["A", "Z", "Σ", "𐐀"] {
			#expect(characters.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in ["a", "σ", "1", "あ"] {
			#expect(!characters.matches(scalar: scalar))
		}
	}

	@Test func binaryは指定した二値プロパティの文字を選ぶ() {
		let characters: CharacterClass = Character.binary(.whitespace)
		for scalar: UnicodeScalar in ["\t", "\n", "\u{85}", "\u{A0}", "　"] {
			#expect(characters.matches(scalar: scalar))
		}
		for scalar: UnicodeScalar in ["A", "\u{200B}", "\u{FEFF}"] {
			#expect(!characters.matches(scalar: scalar))
		}
	}

	@Test func anyの文字列版は各書記素内の全スカラーを含む() {
		let characters: CharacterClass = Character.any("e\u{301}👩‍💻e")
		#expect(characters.asRangeSet.ranges.flatMap { Array($0) }
			== [0x65, 0x301, 0x200D, 0x1F469, 0x1F4BB])
		#expect(characters.matches(scalar: "\u{301}"))
		#expect(characters.matches(scalar: "💻"))
		#expect(!characters.matches(scalar: "é"))
		#expect(!characters.matches(scalar: "x"))
		#expect(Character.any("").asRangeSet.isEmpty)
	}

	@Test func anyの可変長引数版は重複とUnicode両端を扱う() {
		let first: UnicodeScalar = "\0"
		let last: UnicodeScalar = "\u{10FFFF}"
		let characters: CharacterClass = Character.any(first, last, first)
		#expect(characters.asRangeSet.ranges.flatMap { Array($0) }
			== [0, 0x10FFFF])
		#expect(!characters.matches(scalar: "A"))
		#expect(Character.any().asRangeSet.isEmpty)
	}

	@Test func anyの配列版は空配列と複数スカラーを扱う() {
		let scalars: [UnicodeScalar] = ["A", "\u{301}", "😀", "A"]
		let characters: CharacterClass = Character.any(scalars)
		#expect(characters.asRangeSet.ranges.flatMap { Array($0) }
			== [0x41, 0x301, 0x1F600])
		#expect(!characters.matches(scalar: "B"))
		#expect(Character.any([UnicodeScalar]()).asRangeSet.isEmpty)
	}

	@Test func rangeのスカラー版は閉区間の両端を含む() {
		let lower: UnicodeScalar = "a"
		let upper: UnicodeScalar = "c"
		let characters: CharacterClass = Character.range(lower...upper)
		#expect(characters.asRangeSet == RangeSet<UInt32>(0x61..<0x64))
		#expect(characters.matches(scalar: lower))
		#expect(characters.matches(scalar: upper))
		#expect(!characters.matches(scalar: "`"))
		#expect(!characters.matches(scalar: "d"))
		#expect(Character.range(upper...upper).asRangeSet
			== RangeSet<UInt32>(0x63..<0x64))
	}

	@Test func rangeの整数版はUnicode上限の単一文字を扱う() {
		let characters: CharacterClass = Character.range(0x10FFFF...0x10FFFF)
		#expect(characters.asRangeSet == RangeSet<UInt32>(0x10FFFF..<0x110000))
		#expect(characters.matches(scalar: "\u{10FFFF}"))
		#expect(!characters.matches(scalar: "\u{10FFFE}"))
		#expect(!characters.asRangeSet.contains(0x110000))
		#expect(Character.range(0...0).matches(scalar: "\0"))
	}

	@Test func includeの可変長引数版は反転したクラスも合成する() {
		let characters: CharacterClass = Character.include(
			Character.digit.inverted,
			Character.any("5"),
		)
		#expect(characters.matches(scalar: "A"))
		#expect(characters.matches(scalar: "5"))
		#expect(!characters.matches(scalar: "4"))
		#expect(Character.include().asRangeSet.isEmpty)
	}

	@Test func includeの配列版は空配列と重複クラスを扱う() {
		let classes: [CharacterClass] = [
			Character.digit, Character.any("あ"), Character.digit,
		]
		let characters: CharacterClass = Character.include(classes)
		#expect(characters.matches(scalar: "0"))
		#expect(characters.matches(scalar: "9"))
		#expect(characters.matches(scalar: "あ"))
		#expect(!characters.matches(scalar: "A"))
		#expect(Character.include([CharacterClass]()).asRangeSet.isEmpty)
	}

	@Test func excludeの可変長引数版は反転したクラスを除外する() {
		let characters: CharacterClass = Character.exclude(
			Character.digit.inverted,
			Character.any("5"),
		)
		#expect(characters.matches(scalar: "4"))
		#expect(!characters.matches(scalar: "5"))
		#expect(!characters.matches(scalar: "A"))
		#expect(Character.exclude().asRangeSet == Character.all.asRangeSet)
	}

	@Test func excludeの配列版は空配列と入れ子のクラスを扱う() {
		let classes: [CharacterClass] = [
			Character.include([Character.digit, Character.newline]),
			Character.any("あ"),
		]
		let characters: CharacterClass = Character.exclude(classes)
		#expect(characters.matches(scalar: "A"))
		#expect(characters.matches(scalar: "\u{10FFFF}"))
		for scalar: UnicodeScalar in ["0", "9", "\n", "あ"] {
			#expect(!characters.matches(scalar: scalar))
		}
		#expect(Character.exclude([CharacterClass]()).asRangeSet
			== Character.all.asRangeSet)
	}

}
