@_exported import Basis
@_exported import UnitTesting
import SpelluCore


/// 不一致の詳細が追加されても、不一致以外のエラーを許容しない。
func isUnexpectedMatch(
	_ error: any Error,
) -> Bool {
	if case SpelluError.unexpected = error { true } else { false }
}


func expectUnexpectedMatch<R>(
	sourceLocation: Testing.SourceLocation = #_sourceLocation,
	_ operation: () throws -> R,
) {
	let error: SpelluError? = #expect(
		throws: SpelluError.self, sourceLocation: sourceLocation,
	) {
		try operation()
	}
	#expect(
		error.map(isUnexpectedMatch) == true, sourceLocation: sourceLocation,
	)
}
