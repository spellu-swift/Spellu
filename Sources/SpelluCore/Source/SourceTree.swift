import Basis


/// ソースのNodeツリーとTriviaを保持する
public struct SourceTree : Sendable {
	
	public init(
		root: SourceNode,
		trivia: [SourceNode] = []
	) {
		self.root = root
		self.trivia = trivia
	}
	
	public let root: SourceNode
	/// 自動で消費した構文Triviaの範囲。字句空白は含まない。
	public let trivia: [SourceNode]
	
}

extension SourceTree {

	/// 自動Triviaの葉を追加する。
	///
	/// 一回の読み飛ばしの中で隣接する範囲は、一つの葉にまとめる。
	/// 別の読み飛ばしの範囲は、隣接していてもまとめない。
	///
	/// - Parameter continuing: 直前の範囲と同じ読み飛ばしの続きなら `true`。
	package static func appendTrivia(
		grammar: String,
		source: Source,
		range: Range<Int>,
		continuing: Bool,
		to trivia: inout [SourceNode],
	) {
		var begin: Int = range.lowerBound

		if continuing,
			let previous: SourceNode = trivia.last,
			previous.end == begin
		{
			begin = previous.begin
			trivia.removeLast()
		}

		trivia.append(.init(
			grammar: grammar,
			label: "#trivia",
			source: source,
			begin: begin,
			end: range.upperBound,
		))
	}

}
