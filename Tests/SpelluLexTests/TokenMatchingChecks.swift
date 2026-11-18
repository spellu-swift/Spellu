@testable import SpelluLex


enum TokenMatchingEngine : CaseIterable, Equatable, Sendable {
	case matcher
	case vm
	case optimizedVM
}


struct TokenMatchingChecks {

	let engine: TokenMatchingEngine

	func check(
		_ patterns: [TokenIR],
		_ input: String,
		_ expected: String?,
		limit: Int = 65_535,
		sourceLocation: Testing.SourceLocation = #_sourceLocation,
	) {
		// MatcherとVMには、同じ単一のTokenIRを渡す。
		// 一要素は包まず、上限0でもその要素の数量をそのまま評価する。
		let pattern: TokenIR = patterns.count == 1
			? patterns[0] : .sequence(patterns)
		let stream: TokenInputStream = .init(input)
		let expectedEnd: Int? = expected.map { $0.utf8.count }
		let actual: Int?
		let end: Int

		switch engine {
			case .matcher:
				var matcher: TokenMatcher = .init(
					stream: stream, maxRepetition: limit,
				)
				actual = matcher.match(pattern).matchedEnd.map {
					stream.offset(of: $0)
				}
				end = matcher.stream.offset
			case .vm, .optimizedVM:
				let compiler: TokenProgramCompiler = .init(
					optimizeSimpleRepetitions: engine == .optimizedVM,
				)
				var vm: TokenVM = .init(stream: stream, maxRepetition: limit)
				actual = vm.match(compiler.compile(pattern)).matchedEnd.map {
					stream.offset(of: $0)
				}
				end = vm.stream.offset
		}
		#expect(actual == expectedEnd, "input=\(input), engine=\(engine)",
			sourceLocation: sourceLocation)
		#expect(end == (expectedEnd ?? 0), sourceLocation: sourceLocation)
		#expect(stream.offset == 0, sourceLocation: sourceLocation)
	}

}
