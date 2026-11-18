

extension CharacterSet {
	
	public func matches(
		_ string: some StringProtocol,
		caseInsensitive: Bool,
	) -> Int {
		var count: Int = 0
		
		for scalar in string.unicodeScalars {
			guard
				matches(scalar, caseInsensitive: caseInsensitive)
			else { break }
			
			count += 1
		}
		
		return count
	}

	public func matches(
		_ character: Character,
		caseInsensitive: Bool,
	) -> Bool {
		categories.contains {
			$0.matches(character, caseInsensitive: caseInsensitive)
		} != inverted
	}

	public func matches(
		_ scalar: UnicodeScalar,
		caseInsensitive: Bool,
	) -> Bool {
		categories.contains {
			$0.matches(scalar, caseInsensitive: caseInsensitive)
		} != inverted
	}

}


