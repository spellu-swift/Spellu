import Basis
import UnicodeCaseFolding

extension SourceStream {

	/// 記録した原文と、現在位置の入力をScalar単位でケース無視比較する。
	package func matchReference(_ value: String) -> Int? {
		var position: String.Index = cursor
		let limit: String.Index = input.utf8.index(input.startIndex, offsetBy: end)
		for scalar: UnicodeScalar in value.unicodeScalars {
			guard position < limit,
				UnicodeProperty.SimpleCaseFolding.folded(scalar.value)
				== UnicodeProperty.SimpleCaseFolding.folded(
					input.unicodeScalars[position].value
				)
			else { return nil }
			position = input.unicodeScalars.index(after: position)
		}
		return input.utf8.distance(from: input.startIndex, to: position)
	}

}
