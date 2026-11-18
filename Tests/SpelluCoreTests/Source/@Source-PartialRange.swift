@testable import SpelluCore


@Suite
struct SourcePartialRangeTests {

	@Test(arguments: [
		("", 0..<0, 1, 1),
		("abc", 0..<0, 1, 1),
		("abc", 1..<1, 1, 1),
		("abc", 3..<3, 1, 1),
		("abc", 0..<1, 1, 2),
		("abc", 1..<2, 1, 2),
		("abc", 1..<3, 1, 3),
		("xa\nbY", 1..<4, 2, 2),
		("xa\r\nbY", 1..<5, 2, 2),
		("xa\r\nY", 1..<4, 2, 1),
		("x\tbY", 1..<3, 1, 6),
		("前🙂a後", 3..<8, 1, 3),
	])
	func 部分範囲のEOF位置と範囲外位置(
		content: String,
		range: Range<Int>,
		line: Int,
		column: Int,
	) {
		let source: Source
		= .temporary(content, range: .utf8(range))

		#expect(source.range == range)
		#expect(source.eof == (line, column))

		for offset in [Int.min, range.lowerBound - 1, range.upperBound, range.upperBound + 1, Int.max] {
			#expect(source.position(offset) == (line, column))
		}

		let position = source.position(begin: range.lowerBound, end: range.upperBound)
		#expect(position.begin == (1, 1))
		#expect(position.end == (line, column))
	}

	@Test
	func 部分範囲内の位置は本文内の絶対オフセットで指定する() {
		let source: Source
		= .temporary("前🙂a\r\nb-後", range: .utf8(3..<11))
		#expect(source.lines == [3..<8, 10..<11])
		#expect(source.position(3) == (1, 1))  // 🙂
		#expect(source.position(4) == (1, 1))  // 🙂
		#expect(source.position(5) == (1, 1))  // 🙂
		#expect(source.position(6) == (1, 1))  // 🙂
		#expect(source.position(7) == (1, 2))  // a
		#expect(source.position(8) == (1, 3))  // \r\n
		#expect(source.position(10) == (2, 1)) // b
		#expect(source.position(11) == (2, 2)) // eof
		#expect(source.eof == (2, 2))
	}

	@Test
	func 部分範囲のEOFでも指定したタブ幅を使う() {
		let source: Source
		= .temporary("x\tbY", range: .character(1..<3), tabIndentation: 8)
		#expect(source.position(2) == (1, 9))
		#expect(source.position(3) == (1, 10))
		#expect(source.eof == (1, 10))
	}

	@Test
	func 全文Sourceの範囲外は従来どおりEOF位置を返す() {
		let source: Source
		= .temporary("a\nb")
		#expect(source.position(0) == (1, 1))
		#expect(source.position(2) == (2, 1))
		#expect(source.position(-1) == (2, 2))
		#expect(source.position(3) == (2, 2))
		#expect(source.position(Int.max) == (2, 2))
	}
}
