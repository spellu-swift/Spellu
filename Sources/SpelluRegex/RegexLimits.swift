/// 文法の構築と、一回の照合・検索全体に適用する上限。
@available(macOS 15, iOS 18, *)
public struct RegexLimits : Sendable {

	public let maximumPatternScalars: Int
	public let maximumNesting: Int
	public let maximumNodes: Int
	public let maximumCaptures: Int
	public let maximumInputScalars: Int
	public let maximumSteps: Int
	public let maximumBacktracking: Int

	public init(
		maximumPatternScalars: Int = 16_384,
		maximumNesting: Int = 64,
		maximumNodes: Int = 65_536,
		maximumCaptures: Int = 256,
		maximumInputScalars: Int = 1_000_000,
		maximumSteps: Int = 1_000_000,
		maximumBacktracking: Int = 10_000,
	) {
		self.maximumPatternScalars = maximumPatternScalars
		self.maximumNesting = maximumNesting
		self.maximumNodes = maximumNodes
		self.maximumCaptures = maximumCaptures
		self.maximumInputScalars = maximumInputScalars
		self.maximumSteps = maximumSteps
		self.maximumBacktracking = maximumBacktracking
	}

	func validate() throws {
		guard maximumPatternScalars > 0,
			maximumNesting > 0, maximumNesting <= 256,
			maximumNodes > 0, maximumCaptures > 0,
			maximumInputScalars > 0, maximumSteps > 0,
			maximumBacktracking > 0
		else { throw SpelluRegexError.invalidLimits }
	}

}
