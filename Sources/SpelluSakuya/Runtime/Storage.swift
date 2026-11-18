import SpelluCore


final class WorkBudget {

	private var count: Int = 0
	private let maximum: Int

	init(maximum: Int) {
		precondition(maximum >= 0)
		self.maximum = maximum
	}

	func spend() throws {
		guard count < maximum else {
			throw SpelluError.safetyStop(
				.other("Sakuya work limit exceeded (\(maximum))")
			)
		}
		count += 1
	}

}


struct TriviaSpan: Hashable {
	let grammar: GrammarID
	let range: Range<Int>
	/// 直前の範囲と同じ読み飛ばしの続きなら `true`。
	let continuing: Bool
}


/// 前後に付く列のID。確定した子のTrivia列も同じ表で共有する。
enum TriviaContribution: Hashable {
	case none
	case before(Int)
	case after(Int)
	/// 自動Triviaの到達で読み飛ばした範囲を前に置く。認識の後で `before` にする。
	case beforeArrival(Int)
	/// 自動Triviaの到達で読み飛ばした範囲を後に置く。認識の後で `after` にする。
	case afterArrival(Int)
	/// 自動Triviaの到達の読み方。先頭の構文Triviaの範囲と、残りの読み飛ばしの到達。
	case step(GrammarID, Range<Int>, rest: Int)
}


/// 列の分割方法に依存しない内容ハッシュで、同じ列を共有する。
final class SequencePool<Value: Hashable> {

	private enum Contents {
		case empty
		case element(Value)
		case joined(Int, Int)
	}
	private struct Signature: Hashable {
		let count: Int
		let hash: UInt64
	}
	private struct Node {
		let contents: Contents
		let signature: Signature
		let power: UInt64
		let first: Value?
		let last: Value?
	}
	private let budget: WorkBudget
	private var nodes: [Node] = [
		.init(
			contents: .empty,
			signature: .init(count: 0, hash: 0),
			power: 1,
			first: nil,
			last: nil
		)
	]
	private var elements: [Value: Int] = [:]
	private var buckets: [Signature: [Int]] = [:]

	init(_ budget: WorkBudget) { self.budget = budget }

	func single(_ value: Value) throws -> Int {
		if let id: Int = elements[value] {
			return id
		}
		try budget.spend()
		let id: Int = nodes.count
		let signature: Signature = .init(
			count: 1,
			hash: UInt64(bitPattern: Int64(value.hashValue))
		)
		nodes.append(
			.init(
				contents: .element(value),
				signature: signature,
				power: 1_000_003,
				first: value,
				last: value
			)
		)
		elements[value] = id
		buckets[signature, default: []].append(id)
		return id
	}

	func joined(_ left: Int, _ right: Int) throws -> Int {
		if left == 0 {
			return right
		}
		if right == 0 {
			return left
		}
		try budget.spend()
		let a: Node = nodes[left]
		let b: Node = nodes[right]
		let signature: Signature = .init(
			count: a.signature.count + b.signature.count,
			hash: a.signature.hash &* b.power &+ b.signature.hash
		)
		for existing: Int in buckets[signature] ?? [] {
			if case .joined(let a, let b) = nodes[existing].contents,
				a == left, b == right
			{
				return existing
			}
			var source: [Int] = [right, left]
			var target: [Int] = [existing]
			var equal: Bool = true
			while let value: Value = try next(&source) {
				if value != (try next(&target)) {
					equal = false
					break
				}
			}
			if equal {
				return existing
			}
		}
		let id: Int = nodes.count
		nodes.append(
			.init(
				contents: .joined(left, right),
				signature: signature,
				power: a.power &* b.power,
				first: a.first,
				last: b.last
			)
		)
		buckets[signature, default: []].append(id)
		return id
	}

	func next(_ cursor: inout [Int]) throws -> Value? {
		while let id: Int = cursor.popLast() {
			try budget.spend()
			switch nodes[id].contents {
				case .empty: continue
				case .element(let value): return value
				case .joined(let left, let right):
					cursor.append(right)
					cursor.append(left)
			}
		}
		return nil
	}

	func values(_ id: Int) throws -> [Value] {
		var result: [Value] = []
		var cursor: [Int] = [id]
		while let value: Value = try next(&cursor) { result.append(value) }
		return result
	}

	func count(_ id: Int) -> Int { nodes[id].signature.count }

	func first(_ id: Int) -> Value? { nodes[id].first }
	func last(_ id: Int) -> Value? { nodes[id].last }
}


enum ScopeKey: Hashable {
	case leaf
	case fixed(ScopeID)
	case loop(ScopeID, Int, Int?)
}


enum PathAtom: Hashable {
	case model(AtomID)
	case scope(ScopeKey)
	case trivia
}


struct Candidate: Hashable {
	var trees: Int = 0
	var atoms: Int = 0
	var selections: Int = 0
	var rank: Int = 0
	var history: Int = 0
}


final class DerivationStore {

	struct Tree: Hashable {
		let grammar: GrammarID
		let label: Label
		let begin: Int
		let end: Int
		let children: Int
	}
	struct Selection: Hashable {
		let scope: ScopeKey
		let atoms: Int
		let rank: Int
		let children: Int
	}
	struct Iteration: Hashable {
		let previous: Int
		let scope: ScopeKey
		let rank: Int
		let body: Candidate
	}
	enum Ordering { case better, worse, same, unordered }

	let budget: WorkBudget
	let treeLists: IDSequencePool
	let triviaLists: SequencePool<TriviaSpan>
	let atomLists: SequencePool<PathAtom>
	let selectionLists: IDSequencePool
	private(set) var trees: [Tree] = []
	private(set) var selections: [Selection] = [
		.init(scope: .leaf, atoms: 0, rank: 0, children: 0)
	]
	private(set) var iterations: [Iteration] = []
	private var treeIDs: [Tree: Int] = [:]
	private var selectionIDs: [Selection: Int] = [:]
	private var iterationIDs: [Iteration: Int] = [:]

	init(_ budget: WorkBudget) {
		self.budget = budget
		treeLists = .init(budget)
		triviaLists = .init(budget)
		atomLists = .init(budget)
		selectionLists = .init(budget)
	}

	func tree(_ value: Tree) throws -> Int {
		if let id: Int = treeIDs[value] {
			return id
		}
		try budget.spend()
		let id: Int = trees.count
		trees.append(value)
		treeIDs[value] = id
		return id
	}

	func branch(
		_ owner: GrammarID,
		_ label: Label,
		_ children: Int,
		_ cursor: Int
	) throws -> Int {
		try tree(
			.init(
				grammar: owner,
				label: label,
				begin: treeLists.first(children).map { trees[$0].begin }
					?? cursor,
				end: treeLists.last(children).map { trees[$0].end } ?? cursor,
				children: children
			)
		)
	}

	func joined(_ left: Candidate, _ right: Candidate) throws -> Candidate {
		try .init(
			trees: treeLists.joined(left.trees, right.trees),
			atoms: atomLists.joined(left.atoms, right.atoms),
			selections: selectionLists.joined(
				left.selections,
				right.selections
			),
			rank: left.rank + right.rank
		)
	}

	func enclosed(_ value: Candidate, in scope: ScopeKey, rank: Int? = nil)
		throws -> Candidate
	{
		let selection: Selection = .init(
			scope: scope,
			atoms: value.atoms,
			rank: rank ?? value.rank,
			children: value.selections
		)
		let id: Int
		if let existing: Int = selectionIDs[selection] {
			id = existing
		} else {
			try budget.spend()
			id = selections.count
			selections.append(selection)
			selectionIDs[selection] = id
		}
		return try .init(
			trees: value.trees,
			atoms: atomLists.single(.scope(scope)),
			selections: selectionLists.single(id)
		)
	}

	func iteration(_ value: Iteration) throws -> Int {
		if let id: Int = iterationIDs[value] {
			return id
		}
		try budget.spend()
		let id: Int = iterations.count + 1
		iterations.append(value)
		iterationIDs[value] = id
		return id
	}

	func finish(_ history: Int, ending: Candidate) throws -> Candidate {
		var result: Candidate = ending
		var cursor: Int = history
		while cursor != 0 {
			try budget.spend()
			let item: Iteration = iterations[cursor - 1]
			result = try enclosed(
				joined(item.body, result),
				in: item.scope,
				rank: item.rank
			)
			cursor = item.previous
		}
		return result
	}

	func compare(_ left: Int, _ right: Int) throws -> Ordering {
		enum Task {
			case lists(Int, Int)
			case cursor([Int], [Int])
		}
		var pending: [Task] = [.lists(left, right)]
		while let task: Task = pending.popLast() {
			try budget.spend()
			switch task {
				case .lists(let left, let right):
					if left == right {
						continue
					}
					guard
						selectionLists.count(left)
							== selectionLists.count(right)
					else { return .unordered }
					pending.append(.cursor([left], [right]))
				case .cursor(var left, var right):
					let lid: Int? = try selectionLists.next(&left)
					let rid: Int? = try selectionLists.next(&right)
					guard let lid, let rid else {
						if lid != nil || rid != nil {
							return .unordered
						}
						continue
					}
					let a: Selection = selections[lid]
					let b: Selection = selections[rid]
					guard a.scope == b.scope else { return .unordered }
					if a.atoms != b.atoms || a.rank != b.rank {
						if a.rank > b.rank {
							return .better
						}
						if a.rank < b.rank {
							return .worse
						}
						return .unordered
					}
					pending.append(.cursor(left, right))
					pending.append(.lists(a.children, b.children))
			}
		}
		return .same
	}

	func priority(_ value: Candidate) -> Int {
		selectionLists.first(value.selections).map { selections[$0].rank } ?? 0
	}

	func materialize(
		_ roots: Int,
		source: Source,
		model: GrammarModel,
		strategy: TreeStrategy
	) throws -> [SourceNode] {
		struct Frame {
			let tree: Int
			var cursor: [Int]
			var children: [SourceNode] = []
		}
		var output: [SourceNode] = []
		for root: Int in try treeLists.values(roots) {
			var stack: [Frame] = [
				.init(tree: root, cursor: [trees[root].children])
			]
			while !stack.isEmpty {
				try budget.spend()
				let index: Int = stack.count - 1
				if let next: Int = try treeLists.next(&stack[index].cursor) {
					stack.append(
						.init(tree: next, cursor: [trees[next].children])
					)
					continue
				}
				let frame: Frame = stack.removeLast()
				let tree: Tree = trees[frame.tree]
				let grammar: String = model.grammars[tree.grammar.index].name
				var children: [SourceNode] = frame.children
				if strategy == .compact {
					children = []
					var pending: [SourceNode] = frame.children.reversed()
					while let child: SourceNode = pending.popLast() {
						try budget.spend()
						if child.grammar == grammar && child.label.isTemporary {
							pending.append(contentsOf: child.parts.reversed())
						} else {
							children.append(child)
						}
					}
				}
				let node: SourceNode = .init(
					grammar: grammar,
					label: tree.label,
					source: source,
					begin: tree.begin,
					end: tree.end,
					parts: children
				)
				if stack.isEmpty {
					output.append(node)
				} else {
					stack[stack.count - 1].children.append(node)
				}
			}
		}
		return output
	}

}
