@_exported import UnitTesting
import SpelluLex


extension TokenInputStream {

	/// テストでは原文上のUTF-8範囲を簡潔に指定する。
	init(
		_ input: String,
		range: Range<Int>? = nil,
	) {
		let bounds: Range<Int> = range ?? 0..<input.utf8.count
		let lower: String.Index = input.utf8.index(
			input.utf8.startIndex, offsetBy: bounds.lowerBound,
		)
		let upper: String.Index = input.utf8.index(
			input.utf8.startIndex, offsetBy: bounds.upperBound,
		)
		self.init(input: input[lower..<upper])
	}

	var offset: Int {
		offset(of: cursor)
	}

	func offset(
		of cursor: String.Index,
	) -> Int {
		input.base.utf8.distance(from: input.base.startIndex, to: cursor)
	}

}
