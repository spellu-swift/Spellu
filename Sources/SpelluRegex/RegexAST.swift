/// 文法の解析結果から作る、平坦な正規表現AST。
/// 子の番号は親より小さく、Swiftの再帰を使わずに変換できる。
@available(macOS 15, iOS 18, *)
struct RegexAST : Sendable {

	struct Node : Sendable {
		let kind: Kind
		let captures: Range<Int>
	}

	enum Kind : Sendable {
		case character(RegexCharacter)
		case sequence([Int])
		case choice([Int])
		case capture(Int, Int)
		case repetition(Int, RegexQuantifier)
		case assertion(Bool)
		case boundary(Bool)
		case reference([Int])
		case lookahead(Int, positive: Bool)
		case modifiers(Int, RegexModifiers)
	}

	var nodes: [Node] = []
	var root: Int = 0
	var captureCount: Int = 0
	var namedCaptures: [RegexNamedCapture] = []

	mutating func append(
		_ kind: Kind,
		children: [Int] = [],
		capture: Int? = nil,
	) -> Int {
		var lower: Int = capture ?? Int.max
		var upper: Int = capture.map { $0 + 1 } ?? 0
		for child: Int in children {
			let range: Range<Int> = nodes[child].captures
			if !range.isEmpty {
				lower = min(lower, range.lowerBound)
				upper = max(upper, range.upperBound)
			}
		}
		let range: Range<Int> = upper == 0 ? 0..<0 : lower..<upper
		nodes.append(.init(kind: kind, captures: range))
		return nodes.count - 1
	}

}


@available(macOS 15, iOS 18, *)
struct RegexQuantifier : Sendable {
	let minimum: Int
	let maximum: Int?
	let greedy: Bool
}
