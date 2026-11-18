import Basis
import SpelluCore
import UnicodeBinaryProperty
import UnicodeGeneralCategory
import UnicodeCaseFolding


/// 文法上の短縮表記を残し、VMのOptionsで解釈する。
@available(macOS 15, iOS 18, *)
indirect enum RegexCharacter : Sendable {

	case scalar(UInt32)
	case range(ClosedRange<UInt32>)
	case shorthand(UInt32, inverted: Bool)
	case property(RangeSet<UInt32>, inverted: Bool)
	case union([RegexCharacter])
	case inverted(RegexCharacter)
	case dot

	var scalarValue: UInt32? {
		if case let .scalar(value) = self { return value }
		return nil
	}

	func matches(
		_ scalar: UnicodeScalar,
		options: Options,
	) -> Bool {
		let value: UInt32 = scalar.value
		switch self {
			case let .scalar(target):
				return variants(value, options: options).contains(target)
			case let .range(range):
				return variants(value, options: options).contains {
					range.contains($0)
				}
			case let .shorthand(kind, inverted):
				return shorthand(kind, scalar, options: options) != inverted
			case let .property(set, inverted):
				// uモードのPは補集合を作ってからfoldする。
				return variants(value, options: options).contains {
					set.contains($0) != inverted
				}
			case let .union(values):
				return values.contains { $0.matches(scalar, options: options) }
			case let .inverted(value):
				return !value.matches(scalar, options: options)
			case .dot:
				return options.dotMatchesNewlines || !Self.isLine(value)
		}
	}

	static func isLine(_ value: UInt32) -> Bool {
		[10, 13, 0x2028, 0x2029].contains(value)
	}

	private func variants(
		_ value: UInt32,
		options: Options,
	) -> [UInt32] {
		options.ignoresCase
			? UnicodeProperty.SimpleCaseFolding.variants(value) : [value]
	}

	private func shorthand(
		_ kind: UInt32,
		_ scalar: UnicodeScalar,
		options: Options,
	) -> Bool {
		if options.characterSemantics == .spellu {
			let set: RangeSet<UInt32>
			switch kind {
				case 100: set = Self.spelluDigit
				case 119: set = Self.spelluWord
				default: set = Self.spelluSpace
			}
			return variants(scalar.value, options: options).contains {
				set.contains($0)
			}
		}
		switch kind {
			case 100: return (48...57).contains(scalar.value)
			case 119:
				return variants(scalar.value, options: options).contains {
					(48...57).contains($0) || (65...90).contains($0)
						|| (97...122).contains($0) || $0 == 95
				}
			default:
				return [9, 11, 12, 0xFEFF].contains(scalar.value)
					|| Self.isLine(scalar.value)
					|| UnicodeProperty.GeneralCategory.spaceSeparator
						.rangeSet.contains(scalar.value)
		}
	}

	private static let spelluDigit: RangeSet<UInt32>
	= CharacterClass.digit.asRangeSet
	private static let spelluWord: RangeSet<UInt32>
	= CharacterClass.word.asRangeSet
	private static let spelluSpace: RangeSet<UInt32>
	= CharacterClass.include(.space, .newline).asRangeSet

}


/// ECMAScriptの名前検証と、既存UCDライブラリの便宜的な名前を分離する。
@available(macOS 15, iOS 18, *)
struct RegexProperty {

	static func resolve(
		_ name: String,
		semantics: CharacterSemantics,
		range: Range<Int>,
	) throws -> RangeSet<UInt32> {
		let pieces: [Substring] = name.split(
			separator: "=", omittingEmptySubsequences: false,
		)
		if pieces.count == 2 {
			if ["Script", "sc", "Script_Extensions", "scx"].contains(
				String(pieces[0])
			) {
				throw SpelluRegexError.unsupportedFeature(
					range: range, feature: "Script系Unicode Property",
				)
			}
			guard ["General_Category", "gc"].contains(String(pieces[0])),
				let category: UnicodeProperty.GeneralCategory = category(
					String(pieces[1])
				)
			else { throw invalid(range) }
			return scalarSet(category.rangeSet)
		}
		guard pieces.count == 1 else { throw invalid(range) }
		if let category: UnicodeProperty.GeneralCategory = category(name) {
			return scalarSet(category.rangeSet)
		}
		if name == "Any" { return universe }
		if name == "ASCII" { return .init([0..<128]) }
		if name == "Assigned" {
			return universe.subtracting(
				UnicodeProperty.GeneralCategory.unassigned.rangeSet
			)
		}
		let canonical: String = aliases[name] ?? name
		if stringProperties.contains(canonical) {
			throw SpelluRegexError.unsupportedFeature(
				range: range, feature: "文字列のUnicode Property",
			)
		}
		if semantics == .ecmaScript2026 {
			guard allowed.contains(canonical) else { throw invalid(range) }
		}
		guard let property: UnicodeProperty.BinaryProperty
			= .from(canonical)
		else {
			if allowed.contains(canonical) {
				throw SpelluRegexError.unsupportedFeature(
					range: range, feature: "Unicode Property: \(name)",
				)
			}
			throw invalid(range)
		}
		return scalarSet(property.rangeSet)
	}

	static let universe: RangeSet<UInt32> = .init([
		0..<0xD800, 0xE000..<0x110000,
	])

	private static func scalarSet(
		_ set: RangeSet<UInt32>,
	) -> RangeSet<UInt32> {
		set.intersection(universe)
	}

	private static func category(
		_ name: String,
	) -> UnicodeProperty.GeneralCategory? {
		let aliases: [String: String] = [
			"cntrl": "Cc", "digit": "Nd", "punct": "P",
			"Combining_Mark": "M",
		]
		return .from(aliases[name] ?? name)
	}

	private static func invalid(_ range: Range<Int>) -> SpelluRegexError {
		.invalidPattern(range: range, message: "Unicode Property名が不正です。")
	}

	private static let allowed: Set<String> = [
		"ASCII_Hex_Digit", "Alphabetic", "Bidi_Control", "Bidi_Mirrored",
		"Case_Ignorable", "Cased", "Changes_When_Casefolded",
		"Changes_When_Casemapped", "Changes_When_Lowercased",
		"Changes_When_NFKC_Casefolded", "Changes_When_Titlecased",
		"Changes_When_Uppercased", "Dash", "Default_Ignorable_Code_Point",
		"Deprecated", "Diacritic", "Emoji", "Emoji_Component",
		"Emoji_Modifier", "Emoji_Modifier_Base", "Emoji_Presentation",
		"Extended_Pictographic", "Extender", "Grapheme_Base",
		"Grapheme_Extend", "Hex_Digit", "ID_Continue", "ID_Start",
		"Ideographic", "IDS_Binary_Operator", "IDS_Trinary_Operator",
		"Join_Control", "Logical_Order_Exception", "Lowercase", "Math",
		"Noncharacter_Code_Point", "Pattern_Syntax", "Pattern_White_Space",
		"Quotation_Mark", "Radical", "Regional_Indicator",
		"Sentence_Terminal", "Soft_Dotted", "Terminal_Punctuation",
		"Unified_Ideograph", "Uppercase", "Variation_Selector", "White_Space",
		"XID_Continue", "XID_Start",
	]

	private static let stringProperties: Set<String> = [
		"Basic_Emoji", "Emoji_Keycap_Sequence", "RGI_Emoji",
		"RGI_Emoji_Modifier_Sequence", "RGI_Emoji_Flag_Sequence",
		"RGI_Emoji_Tag_Sequence", "RGI_Emoji_ZWJ_Sequence",
	]

	private static let aliases: [String: String] = [
		"AHex": "ASCII_Hex_Digit", "Alpha": "Alphabetic",
		"Bidi_C": "Bidi_Control", "Bidi_M": "Bidi_Mirrored",
		"CI": "Case_Ignorable", "CWCF": "Changes_When_Casefolded",
		"CWCM": "Changes_When_Casemapped", "CWL": "Changes_When_Lowercased",
		"CWKCF": "Changes_When_NFKC_Casefolded",
		"CWT": "Changes_When_Titlecased", "CWU": "Changes_When_Uppercased",
		"DI": "Default_Ignorable_Code_Point", "Dep": "Deprecated",
		"Dia": "Diacritic", "EComp": "Emoji_Component",
		"EMod": "Emoji_Modifier", "EBase": "Emoji_Modifier_Base",
		"EPres": "Emoji_Presentation", "ExtPict": "Extended_Pictographic",
		"Ext": "Extender", "Gr_Base": "Grapheme_Base",
		"Gr_Ext": "Grapheme_Extend", "Hex": "Hex_Digit",
		"IDC": "ID_Continue", "IDS": "ID_Start", "Ideo": "Ideographic",
		"IDSB": "IDS_Binary_Operator", "IDST": "IDS_Trinary_Operator",
		"Join_C": "Join_Control", "LOE": "Logical_Order_Exception",
		"Lower": "Lowercase", "NChar": "Noncharacter_Code_Point",
		"Pat_Syn": "Pattern_Syntax", "Pat_WS": "Pattern_White_Space",
		"QMark": "Quotation_Mark", "RI": "Regional_Indicator",
		"STerm": "Sentence_Terminal", "SD": "Soft_Dotted",
		"Term": "Terminal_Punctuation", "UIdeo": "Unified_Ideograph",
		"Upper": "Uppercase", "VS": "Variation_Selector",
		"space": "White_Space", "WSpace": "White_Space",
		"XIDC": "XID_Continue", "XIDS": "XID_Start",
	]

}
