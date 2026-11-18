import Basis
import UnicodeBinaryProperty
import UnicodeGeneralCategory
import UnicodeCaseFolding


extension CharacterPattern {
	
	func matches(
		_ character: Character,
		caseInsensitive: Bool = false,
	) -> Bool {
		let scalars = character.unicodeScalars

		guard
			scalars.count == 1,
			let scalar = scalars.first
		else { return false }

		return matches(scalar, caseInsensitive: caseInsensitive)
	}

	public func matches(
		_ scalar: UnicodeScalar,
		caseInsensitive: Bool = false,
	) -> Bool {
		switch self {
		case .all:
			true

		case .space:
			// [\p{Zs}\u{0009}]
			// [\u{0009}\u{0020}\u{00A0}\u{1680}\u{2000}-\u{200A}\u{202F}\u{205F}\u{3000}]
			scalar.properties.generalCategory == .spaceSeparator
				|| scalar == "\t"

		case .newline:
			// [\p{Zl}\p{Zp}\n\r]
			// [\u{000A}\u{000D}\u{2028}-\u{2029}]
			scalar.properties.generalCategory == .lineSeparator
				|| scalar.properties.generalCategory == .paragraphSeparator
				|| scalar == "\n"
				|| scalar == "\r"

		case .any(let scalars):
			if caseInsensitive {
				{
					let folded = UnicodeProperty.SimpleCaseFolding.folded(scalar.value)

					return scalars.contains {
						UnicodeProperty.SimpleCaseFolding.folded($0)
						==
						folded
					}
				}()
			}
			else {
				scalars.contains(scalar.value)
			}

		case .range(let range):
			range.contains(scalar, caseInsensitive: caseInsensitive)

		case .general(let category):
			category.ranges.contains(scalar.value, caseInsensitive: caseInsensitive)
			
		case .binary(let property):
			property.ranges.contains(scalar.value, caseInsensitive: caseInsensitive)
			
		case .set(let set):
			set.matches(scalar, caseInsensitive: caseInsensitive)
		}
	}
	
}
