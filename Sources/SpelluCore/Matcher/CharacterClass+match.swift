import Basis
import SpelluLex


extension CharacterClass {
	
	@inlinable
	public func matches(
		_ character: Character,
		caseInsensitive: Bool = false,
	) -> Bool {
		set.matches(character, caseInsensitive: caseInsensitive)
	}

	@inlinable
	public func matches(
		scalar: UnicodeScalar,
		caseInsensitive: Bool = false,
	) -> Bool {
		set.matches(scalar, caseInsensitive: caseInsensitive)
	}

	@inlinable
	public func matches(
		scalar: Int,
		caseInsensitive: Bool = false,
	) -> Bool {
		guard
			let scalar = UnicodeScalar(scalar)
		else { preconditionFailure() }

		return set.matches(scalar, caseInsensitive: caseInsensitive)
	}

}
