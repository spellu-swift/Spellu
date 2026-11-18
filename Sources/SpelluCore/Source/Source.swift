import Basis


public enum SourceRange {
	
	case whole
	case utf8(any RangeExpression<Int>)
	case character(any RangeExpression<Int>)

}


extension Source {
	
	@inlinable
	public static func temporary(
		_ string: String,
		range: SourceRange = .whole,
		tabIndentation: Int? = nil,
	) -> Source {
		.init(
			location: .temporary,
			content: string,
			range: range,
			tabIndentation: tabIndentation,
		)
	}

	@inlinable
	public static func memory(
		name: String,
		_ string: String,
		range: SourceRange = .whole,
		tabIndentation: Int? = nil,
	) -> Source {
		.init(
			location: .memory(name),
			content: string,
			range: range,
			tabIndentation: tabIndentation,
		)
	}
		
	@inlinable
	public static func file(
		path: FilePath,
		range: SourceRange = .whole,
		tabIndentation: Int? = nil,
	) throws -> Source {
		let string: String = try path.file.text
		
		return .init(
			location: .file(path),
			content: string,
			range: range,
			tabIndentation: tabIndentation,
		)
	}
		
}


///
/// ソース
///
public final class Source : Sendable {

	public init(
		location: SourceLocation,
		content: String,
		range: SourceRange = .whole,
		tabIndentation: Int? = nil,
	) {
		let range: Range<Int>
		= {
			switch range {
				case .whole:
					return 0..<content.utf8.count

				case .utf8(let range):
					return range.relative(to: 0..<content.utf8.count)
					
				case .character(let range):
					let _range = range.relative(to: 0..<content.count)

					return
						content.utf8Offset(content.index(at: _range.lowerBound))
						..<
						content.utf8Offset(content.index(at: _range.upperBound))
			}
		}()

		self.location = location
		self.content = content
		self.range = range
		self.tabIndentation = tabIndentation ?? 4
		self._lines = .init(nil)
	}
	
	public  let location: SourceLocation
	public  let content: String
	public  let range: Range<Int>
	public  let tabIndentation: Int
	private let _lines: Barrier<[Range<Int>]?> // キャッシュデータ

	@inlinable
	public var asString: String {
		content.utf8[range].asString
	}
	
	@inlinable
	public var asSubstring: Substring {
		content[indexRange]
	}
	
	@inlinable
	public var indexRange: Range<String.Index> {
		content.utf8.index(content.utf8.startIndex, offsetBy: range.lowerBound)
		..<
		content.utf8.index(content.utf8.startIndex, offsetBy: range.upperBound)
	}
	
}


extension Source : ExpressibleByStringLiteral {
	
	public convenience init(
		stringLiteral content: StringLiteralType,
	) {
		self.init(
			location: .temporary,
			content: content,
			tabIndentation: nil,
		)
	}

}


extension Source : Equatable {
	
	public static func == (
		lhs: Source,
		rhs: Source,
	) -> Bool {
		lhs.location == rhs.location
		&& lhs.range == rhs.range
	}
	
}


extension Source {
	
	/// ソース内の最初の改行文字
	public var firstNewLineCharacter: Character? {
		content[range].first {
			$0.isNewline
		}
	}
	
	/// 改行文字を判定する
	public func detectNewLineCharacter(
		default: Character,
	) -> Character {
		firstNewLineCharacter ?? `default`
	}

}


extension Source {
	
	public var lines: [Range<Int>] {
		_lines.atomic { lines in
			if let lines {
				return lines
			}

			let result: [Range<Int>]
			= split()
			
			lines = result
			
			return result
		}
	}

	func split(
	) -> [Range<Int>] {
		return content[indexRange]
			.split(
				omittingEmptySubsequences: false,
			) { character in
				character.isNewline
			}
			.map {
				content.utf8.distance(from: content.utf8.startIndex, to: $0.startIndex)
				..<
				content.utf8.distance(from: content.utf8.startIndex, to: $0.endIndex)
			}
	}
	
	public func position(
		begin: Int,
		end: Int,
	) -> (begin: (line: Int, column: Int), end: (line: Int, column: Int)) {
		(
			position(begin),
			position(end),
		)
	}

	public func position(
		_ offset: Int,
	) -> (line: Int, column: Int) {
		let range: Range<Int>
		= self.range

		// 部分範囲の末尾もEOFとし、範囲外の位置はEOFへ丸める。
		guard
			offset >= range.lowerBound && offset < range.upperBound
		else { return eof }
		
		let lines: [Range<Int>] = self.lines
		
		for index in 0..<lines.count {
			let line: Range<Int> = lines[index]
			
			if offset >= line.lowerBound {
				// 行中
				if offset < line.upperBound {
					return self.line(
						index: index,
						offset: offset,
					)
				}
				
				// 改行
				let nextLine: Range<Int>? = lines.get(at: index + 1)
				
				if offset < nextLine?.lowerBound ?? -1 {
					return self.line(
						index: index,
						offset: offset,
					)
				}
			}
		}
		
		preconditionFailure()
//		return (-1, -1)
	}

	public var eof: (line: Int, column: Int) {
		let lines: [Range<Int>] = self.lines
		
		guard
			lines.isNotEmpty
		else { return (1, 1) }
		
		return line(
			index: lines.count - 1,
			offset: range.upperBound,
		)
	}

	/// 行番号を用いて、行の文字列を返す。
	/// タブをスペースに変換する。
	public func line(
		_ line: Int,
	) -> String {
		guard
			line >= 1,
			line < lines.count
		else { return "" }
		
		return expandTab(content[utf8: lines[line - 1]])
	}
	
	func expandTab(
		_ string: Substring
	) -> String {
		precondition(tabIndentation > 0)

		var result = String()
		result.reserveCapacity(string.utf8.count)

		var column = 0

		for character in string {
			switch character {
			case "\t":
				let trivia = tabIndentation - column % tabIndentation
				result.append(contentsOf: repeatElement(" ", count: trivia))
				column += trivia

//			case "\r", "\n", "\r\n":
//				result.append(character)
//				column = 0

			default:
				result.append(character)
				column += 1
			}
		}

		return result
	}
	
	func line(
		index: Int,
		offset: Int,
	) -> (Int, Int) {
		let column: Int
		= column(line: index, offset: offset)

		return (
			index + 1,
			column,
		)
	}

	func column(
		line index: Int,
		offset: Int,
	) -> Int {
		guard
			index >= 0 && index < lines.count
		else { return -1 }
		
		let string: Substring
		= content[utf8: lines[index].lowerBound..<offset]

		return column(string: string)
	}
	
	/// Character Offsetを返す
	func column(
		string: Substring,
	) -> Int {
		var column: Int = 0

		for char in string {
			if char == "\t" {
				column = ((column / tabIndentation) + 1) * tabIndentation
			} else {
				column += 1
			}
		}
		
		return column + 1
	}
	
}


extension String {
	
	public subscript (
		utf8 range: Range<Int>,
	) -> Substring {
		self[
			utf8Index(range.lowerBound)
			..<
			utf8Index(range.upperBound)
		]
	}
	
}
