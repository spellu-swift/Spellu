

/// 原文のIndexを維持した入力範囲と、評価器ごとに独立した現在位置。
package struct TokenInputStream {
	
	package init(
		input: Substring,
		cursor: String.Index? = nil,
	) {
		self.input = input
		self.cursor = cursor ?? input.startIndex
		self.farthestFailure = self.cursor
	}
	
	package let input: Substring
	package var cursor: String.Index
	private(set) var farthestFailure: String.Index
	
}


extension TokenInputStream {

	/// 巻き戻しとは独立して、今回の照合の最遠失敗位置を記録する。
	mutating func recordFailure(
		at position: String.Index? = nil,
	) {
		farthestFailure = max(farthestFailure, position ?? cursor)
	}

	mutating func resetFailure() {
		farthestFailure = cursor
	}

	mutating func scanNext(
	) -> UnicodeScalar? {
		guard
			cursor < input.endIndex
		else { return nil }

		let scalar: UnicodeScalar
		= input.unicodeScalars[cursor]

		cursor = input.unicodeScalars.index(after: cursor)

		return scalar
	}

	/// 一括照合に成功した場合にだけ、原文上のカーソルを進める。
	mutating func match(
		string: String,
		byteCount: Int,
	) -> TokenMatchResult {
		if
			cursor <= input.endIndex,
			let after: String.Index
				= input.utf8.index(
					cursor,
					offsetBy: byteCount,
					limitedBy: input.endIndex,
				),
			input.utf8[cursor..<after]
				.elementsEqual(string.utf8)
		{
			cursor = after
			return .success(after)
		}

		// 一括比較に失敗した場合だけ、不一致のScalarの位置を求める。
		var position: String.Index = cursor
		for scalar: UnicodeScalar in string.unicodeScalars {
			guard position < input.endIndex,
				input.unicodeScalars[position] == scalar
			else { break }
			position = input.unicodeScalars.index(after: position)
		}
		recordFailure(at: position)
		return .failure(position)
	}

}
