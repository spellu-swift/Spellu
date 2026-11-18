import Basis


extension RangeExpression where Bound == UInt32 {
	
	@inlinable
	public func contains(
		_ scalar: UnicodeScalar,
		caseInsensitive: Bool,
	) -> Bool {
		contains(
			scalar.value,
			caseInsensitive: caseInsensitive,
		)
	}

	public func contains(
		_ scalar: UInt32,
		caseInsensitive: Bool,
	) -> Bool {
		if caseInsensitive {
			UnicodeProperty.SimpleCaseFolding
				.variants(scalar)
				.contains { self.contains($0) }
		}
		else {
			self.contains(scalar)
		}
	}
	
}


extension [ClosedRange<UInt32>] {

	@inlinable
	public func contains(
		_ scalar: UnicodeScalar,
		caseInsensitive: Bool,
	) -> Bool {
		contains(
			scalar.value,
			caseInsensitive: caseInsensitive,
		)
	}

	public func contains(
		_ scalar: UInt32,
		caseInsensitive: Bool,
	) -> Bool {
		if caseInsensitive {
			UnicodeProperty.SimpleCaseFolding
				.variants(scalar)
				.contains { self.contains($0) }
		}
		else {
			self.contains(scalar)
		}
	}

	@inlinable
	public func contains(
		_ scalar: UInt32,
	) -> Bool {
		self.contains { $0.contains(scalar) }
	}

}


extension RangeSet where Bound == UInt32 {

	@inlinable
	public func contains(
		_ scalar: UnicodeScalar,
		caseInsensitive: Bool,
	) -> Bool {
		contains(
			scalar.value,
			caseInsensitive: caseInsensitive,
		)
	}

	public func contains(
		_ scalar: UInt32,
		caseInsensitive: Bool,
	) -> Bool {
		if caseInsensitive {
			UnicodeProperty.SimpleCaseFolding
				.variants(scalar)
				.contains { self.contains($0) }
		}
		else {
			self.contains(scalar)
		}
	}

}
