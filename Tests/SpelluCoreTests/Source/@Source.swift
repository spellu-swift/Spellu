@testable import SpelluCore


@Suite struct SourceTests {
	
	
	@Test func Source_of_String() {
		let input: String = "abc"
		
		let source: Source = .temporary(input)
		
		#expect(source.range == 0..<3)
	}
	
	
	@Test func Source_of_Substring() {
		let source: Source = .temporary("abc", range: .character(1...))
		
		#expect(source.range == 1..<3)
	}
	
	
	
	@Test func range_1() throws {
		#expect("abcdef" == "abcdef")
		#expect("abcdef"[1..<3] == "bc")
		#expect("abcdef"[1...3] == "bcd")
		#expect("abcdef"[1...] == "bcdef")
		#expect("abcdef"[..<3] == "abc")
		#expect("abcdef"[...3] == "abcd")
		
		#expect(Source.temporary("abcdef").range == 0..<6)
		#expect(Source.temporary("abcdef", range: .character(1..<3)).range == 1..<3)
		#expect(Source.temporary("abcdef", range: .character(1...3)).range == 1..<4)
		#expect(Source.temporary("abcdef", range: .character(1...)).range == 1..<6)
		#expect(Source.temporary("abcdef", range: .character(..<3)).range == 0..<3)
		#expect(Source.temporary("abcdef", range: .character(...3)).range == 0..<4)
	}
	
	
	@Test func lines_1() throws {
		let source: Source = .temporary("abc\ndef")
		
		#expect(source.lines == [
			0..<3,
			4..<7,
		])
	}
	
	
	@Test func lines_1_1() throws {
		let source: Source = .temporary("abc\r\ndef")
		
		#expect(source.lines == [
			0..<3,
			5..<8,
		])
	}
	
	
	@Test func lines_2() throws {
		let source: Source = .temporary("abc\ndef\n")
		
		#expect(source.lines == [
			0..<3,
			4..<7,
			8..<8,
		])
	}
	
	
	@Test func lines_3() throws {
		let source: Source = .temporary("\nabc\ndef\n")
		
		#expect(source.lines == [
			0..<0,
			1..<4,
			5..<8,
			9..<9,
		])
	}
	
	
	@Test func location_1() throws {
		let source: Source = .temporary("abc")

		#expect(source.position(0) == (1, 1))
	}
	
	
	@Test func location_2() throws {
		let source: Source = .temporary("abc")

		#expect(source.position(0) == (1, 1)) // "a"
		#expect(source.position(1) == (1, 2)) // "b"
		#expect(source.position(2) == (1, 3)) // "c"
		#expect(source.position(3) == (1, 4)) // EOF
		#expect(source.position(4) == (1, 4)) // EOF
	}
	
	
	@Test func location_3() throws {
		let source: Source = .temporary("""

abc
def

""")
		
		#expect(source.lines == [
			0..<0,
			1..<4,
			5..<8,
			9..<9,
		])
		
		#expect(source.position(0) == (1, 1)) // LF
		#expect(source.position(1) == (2, 1)) // "a"
		#expect(source.position(2) == (2, 2)) // "b"
		#expect(source.position(3) == (2, 3)) // "c"
		#expect(source.position(4) == (2, 4)) // LF
		#expect(source.position(5) == (3, 1)) // "d"
		#expect(source.position(6) == (3, 2)) // "e"
		#expect(source.position(7) == (3, 3)) // "f"
		#expect(source.position(8) == (3, 4)) // LF
		#expect(source.position(9) == (4, 1)) // EOF
	}

	
	@Test func location_4() throws {
		let source: Source = .temporary("a\tb")

		#expect(source.position(2) == (1, 5)) // "b"
	}
	
	
	@Test func tab() {
		let source: Source = .temporary("a\tb")
		#expect(source.line(index: 0, offset: 0) == (1, 1))
		#expect(source.line(index: 0, offset: 1) == (1, 2))
		#expect(source.line(index: 0, offset: 2) == (1, 5))
	}

	@Test
	func UTF8のEOFオフセットから最終列を返す() {
		let source: Source = .temporary("日🙂")
		#expect(source.range.upperBound == 7)
		#expect(source.eof == (1, 3))
		#expect(source.position(7) == (1, 3))
		#expect(source.position(begin: 0, end: 7).end == (1, 3))
	}
	
	@Test
	func エラーメッセージ用データ() throws {
		let source: Source
		= "--\n\tlet 4 = 0\n--"
		
		let (line, column)
		= source.position(8)
		
		#expect(source.line(line) == "    let 4 = 0")
		#expect((line, column) == (2, 9))
	}

}


