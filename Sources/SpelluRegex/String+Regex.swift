@available(macOS 15, iOS 18, *)
extension StringProtocol {

	public func wholeMatch(
		of pattern: SpelluRegex,
	) throws -> Match? {
		try pattern.wholeMatch(in: self)
	}

	public func prefixMatch(
		of pattern: SpelluRegex,
	) throws -> Match? {
		try pattern.prefixMatch(in: self)
	}

	public func firstMatch(
		of pattern: SpelluRegex,
	) throws -> Match? {
		try pattern.firstMatch(in: self)
	}

}
