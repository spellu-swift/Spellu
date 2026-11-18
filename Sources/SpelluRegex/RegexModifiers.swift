/// 局所修飾子の変更分。文字集合のプロファイルは変更しない。
@available(macOS 15, iOS 18, *)
struct RegexModifiers : Sendable {
	let add: RegexFlags
	let remove: RegexFlags
}


@available(macOS 15, iOS 18, *)
struct RegexFlags : OptionSet, Sendable {
	let rawValue: UInt8

	static let ignoresCase: Self = .init(rawValue: 1)
	static let multiline: Self = .init(rawValue: 2)
	static let dotMatchesNewlines: Self = .init(rawValue: 4)
}


@available(macOS 15, iOS 18, *)
extension Options {

	var flags: RegexFlags {
		var flags: RegexFlags = []
		if ignoresCase { flags.insert(.ignoresCase) }
		if multiline { flags.insert(.multiline) }
		if dotMatchesNewlines { flags.insert(.dotMatchesNewlines) }
		return flags
	}

	func applying(_ flags: RegexFlags) -> Options {
		.init(
			characterSemantics: characterSemantics,
			ignoresCase: flags.contains(.ignoresCase),
			multiline: flags.contains(.multiline),
			dotMatchesNewlines: flags.contains(.dotMatchesNewlines),
			limits: limits,
		)
	}

}
