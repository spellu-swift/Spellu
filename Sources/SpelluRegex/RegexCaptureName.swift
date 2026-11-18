import Basis
import UnicodeBinaryProperty


/// Stringの正規等価比較を避け、名前を符号列として比較する。
@available(macOS 15, iOS 18, *)
struct RegexCaptureName : Hashable, Sendable {

	let scalars: [UInt32]
	private static let starts: RangeSet<UInt32>
	= UnicodeProperty.BinaryProperty.idStart.rangeSet
	private static let continues: RangeSet<UInt32>
	= UnicodeProperty.BinaryProperty.idContinue.rangeSet

	var string: String {
		String(String.UnicodeScalarView(scalars.map { UnicodeScalar($0)! }))
	}

	init(
		_ raw: String,
		range: Range<Int>,
	) throws {
		let input: [UnicodeScalar] = Array(raw.unicodeScalars)
		var decoded: [UInt32] = []
		var index: Int = 0
		while index < input.count {
			let value: UInt32
			if input[index] != "\\" {
				value = input[index].value
				index += 1
			} else {
				let start: Int = index
				guard index + 2 < input.count, input[index + 1] == "u" else {
					throw Self.invalid(range)
				}
				index += 2
				if input[index] == "{" {
					index += 1
					while index < input.count && input[index] != "}" {
						index += 1
					}
					guard index < input.count else { throw Self.invalid(range) }
					index += 1
				} else {
					guard index + 4 <= input.count else {
						throw Self.invalid(range)
					}
					index += 4
					let prefix: String = String(String.UnicodeScalarView(
						input[start..<index]
					))
					if let high: UInt32 = RegexEscapedScalar.value(prefix),
						(0xD800...0xDBFF).contains(high),
						index + 6 <= input.count,
						input[index] == "\\", input[index + 1] == "u" {
						index += 6
					}
				}
				let token: String = String(String.UnicodeScalarView(
					input[start..<index]
				))
				guard let scalar: UInt32 = RegexEscapedScalar.value(token),
					UnicodeScalar(scalar) != nil
				else { throw Self.invalid(range) }
				value = scalar
			}
			let valid: Bool
			if decoded.isEmpty {
				valid = value == 36 || value == 95
					|| Self.starts.contains(value)
			} else {
				valid = value == 36 || value == 95 || value == 0x200C
					|| value == 0x200D
					|| Self.continues.contains(value)
			}
			guard valid else { throw Self.invalid(range) }
			decoded.append(value)
		}
		guard !decoded.isEmpty else { throw Self.invalid(range) }
		scalars = decoded
	}

	private static func invalid(_ range: Range<Int>) -> SpelluRegexError {
		.invalidPattern(range: range, message: "捕捉名が不正です。")
	}
}


@available(macOS 15, iOS 18, *)
struct RegexNamedCapture : Sendable {
	let name: RegexCaptureName
	var captures: [Int]
}


/// Unicode escapeの値を、サロゲートを含めて損失なく復号する。
/// Scalarとして使えるかの検査は呼出元が行う。
@available(macOS 15, iOS 18, *)
struct RegexEscapedScalar {
	static func value(_ raw: String) -> UInt32? {
		if raw.hasPrefix("\\u{") && raw.hasSuffix("}") {
			let digits: Substring = raw.dropFirst(3).dropLast()
			return hex(digits).flatMap { $0 <= 0x10FFFF ? $0 : nil }
		}
		if raw.utf8.count == 12, raw.hasPrefix("\\u"),
			raw.dropFirst(6).hasPrefix("\\u"),
			let high: UInt32 = hex(raw.dropFirst(2).prefix(4)),
			let low: UInt32 = hex(raw.suffix(4)),
			(0xD800...0xDBFF).contains(high),
			(0xDC00...0xDFFF).contains(low) {
			return 0x10000 + (high - 0xD800) * 1024 + low - 0xDC00
		}
		if raw.hasPrefix("\\u"), raw.utf8.count == 6 {
			return hex(raw.dropFirst(2))
		}
		if raw.hasPrefix("\\x"), raw.utf8.count == 4 {
			return hex(raw.dropFirst(2))
		}
		return nil
	}

	private static func hex(_ digits: Substring) -> UInt32? {
		guard !digits.isEmpty, digits.utf8.allSatisfy({
			(48...57).contains($0) || (65...70).contains($0)
				|| (97...102).contains($0)
		}) else { return nil }
		return UInt32(digits, radix: 16)
	}
}
