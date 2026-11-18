import Basis


public struct SourceFragment : Sendable {
	
	public init(
		source: Source,
		begin: Int,
		end: Int,
	) {
		self.source = source
		self.begin = begin
		self.end = end
	}
	
	public let source: Source
	public let begin: Int
	public let end: Int
	

	@inlinable
	public var range: Range<Int> {
		begin..<end
	}

	@inlinable
	public var position: (Int, Int) {
		source.position(begin)
	}

	@inlinable
	public var string: String {
		substring.asString
	}
	
	@inlinable
	public var substring: Substring {
		source.content[utf8: begin..<end]
	}
	
}


extension SourceFragment : Equatable {}


extension SourceFragment {
	
	public static func temporary(
		_ string: String,
		_ range: some RangeExpression<Int> = 0...,
		tabIndentation: Int? = nil,
	) -> Self {
		let range: Range<Int>
		= range.relative(
			to: 0..<string.count,
		)
		
		return Self(
			source: .temporary(
				string,
				tabIndentation: tabIndentation,
			),
			begin: range.lowerBound,
			end: range.upperBound,
		)
	}
	
}
