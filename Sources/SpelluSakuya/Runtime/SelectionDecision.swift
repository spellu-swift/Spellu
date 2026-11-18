import Basis
import SpelluCore



/// 基準の順序と複製IDで変数順序を固定する。0と1は偽・真。
final class DecisionDiagram {
	struct Node: Hashable {
		let variable: Int
		let branches: [Int]
	}
	struct Pair: Hashable {
		let left: Int
		let right: Int
	}
	private(set) var nodes: [Node] = [
		.init(variable: .max, branches: []),
		.init(variable: .max, branches: []),
	]
	private(set) var widths: [Int] = []
	private var orders: [Int] = []
	private(set) var origins: [Int] = []
	private var index: [Node: Int] = [:]
	private var conjunctions: [Pair: Int] = [:]
	private var complements: [Int: Int] = [0: 1, 1: 0]
	let step: () throws -> Void

	init(step: @escaping () throws -> Void) { self.step = step }

	func variable(width: Int) throws -> Int {
		try step()
		precondition(width > 1)
		orders.append(widths.count)
		origins.append(widths.count)
		widths.append(width)
		return widths.count - 1
	}

	/// 遅延して作る独立な使用箇所も、元の変数の親子順を守る。
	func replica(of original: Int) throws -> Int {
		try step()
		orders.append(orders[original])
		origins.append(origins[original])
		widths.append(widths[original])
		return widths.count - 1
	}

	func precedes(_ left: Int, _ right: Int) -> Bool {
		if right == .max { return left != .max }
		if left == .max { return false }
		return (orders[left], left) < (orders[right], right)
	}

	func node(_ variable: Int, _ branches: [Int]) throws -> Int {
		try step()
		precondition(branches.count == widths[variable])
		if branches.allSatisfy({ $0 == branches[0] }) { return branches[0] }
		let key: Node = .init(variable: variable, branches: branches)
		if let known: Int = index[key] { return known }
		for child: Int in branches {
			try step()
			precondition(precedes(variable, nodes[child].variable))
		}
		let id: Int = nodes.count
		nodes.append(key)
		index[key] = id
		return id
	}

	func equals(_ variable: Int, _ value: Int) throws -> Int {
		var branches: [Int] = Array(repeating: 0, count: widths[variable])
		branches[value] = 1
		return try node(variable, branches)
	}

	func and(_ a: Int, _ b: Int) throws -> Int {
		func key(_ a: Int, _ b: Int) -> Pair {
			.init(left: min(a, b), right: max(a, b))
		}
		func known(_ p: Pair) -> Int? {
			if p.left == 0 { return 0 }
			if p.left == 1 || p.left == p.right { return p.right }
			return conjunctions[p]
		}
		let root: Pair = key(a, b)
		var pending: [Pair] = [root]
		while let pair: Pair = pending.last {
			try step()
			if known(pair) != nil { pending.removeLast(); continue }
			let left: Node = nodes[pair.left]
			let right: Node = nodes[pair.right]
			let variable: Int = precedes(left.variable, right.variable)
				? left.variable : right.variable
			var children: [Int] = []
			var missing: Pair?
			for value: Int in 0..<widths[variable] {
				try step()
				let child: Pair = key(
					left.variable == variable ? left.branches[value] : pair.left,
					right.variable == variable ? right.branches[value] : pair.right
				)
				guard let found: Int = known(child) else {
					missing = child
					break
				}
				children.append(found)
			}
			if let missing { pending.append(missing); continue }
			conjunctions[pair] = try node(variable, children)
			pending.removeLast()
		}
		return known(root)!
	}

	func not(_ root: Int) throws -> Int {
		var pending: [Int] = [root]
		while let id: Int = pending.last {
			try step()
			if complements[id] != nil { pending.removeLast(); continue }
			let value: Node = nodes[id]
			if let child: Int = value.branches.first(where: {
				complements[$0] == nil
			}) { pending.append(child); continue }
			let inverse: Int = try node(
				value.variable, value.branches.map { complements[$0]! }
			)
			complements[id] = inverse
			complements[inverse] = id
			pending.removeLast()
		}
		return complements[root]!
	}

	func or(_ a: Int, _ b: Int) throws -> Int {
		if a == 0 { return b }
		if b == 0 || a == b { return a }
		return try not(and(not(a), not(b)))
	}

	/// 指定した起源に属さない変数を存在量化する。
	func project(_ root: Int, keepingOrigins variables: Set<Int>) throws -> Int {
		var memo: [Int: Int] = [0: 0, 1: 1]
		var pending: [Int] = [root]
		while let id: Int = pending.last {
			if memo[id] != nil { pending.removeLast(); continue }
			try step()
			let value: Node = nodes[id]
			if let child: Int = value.branches.first(where: { memo[$0] == nil }) {
				pending.append(child)
				continue
			}
			let branches: [Int] = value.branches.map { memo[$0]! }
			if variables.contains(origins[value.variable]) {
				memo[id] = try node(value.variable, branches)
			}
			else {
				var union: Int = 0
				for branch: Int in branches { union = try or(union, branch) }
				memo[id] = union
			}
			pending.removeLast()
		}
		return memo[root]!
	}

	func witness(_ root: Int) throws -> [Int: Int] {
		precondition(root != 0)
		var id: Int = root
		var assignment: [Int: Int] = [:]
		while id > 1 {
			try step()
			let value: Node = nodes[id]
			let choice: Int = value.branches.firstIndex(where: { $0 != 0 })!
			assignment[value.variable] = choice
			id = value.branches[choice]
		}
		return assignment
	}
}
