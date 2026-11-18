import Basis
import SpelluCore



/// 循環文脈を含む式テンプレート。使用箇所はまだ展開しない。
final class PackedPlan {
	struct Key: Hashable {
		let result: Int
		let active: Set<Int>
	}
	struct Branch {
		let action: DerivationAction
		let children: [Int]
		let trivia: TriviaContribution
	}
	struct Plan {
		let result: Int
		let families: [Branch]
		let support: Set<Int>
		let hasTrivia: Bool
	}
	struct TriviaBranch {
		let contribution: TriviaContribution
		let children: [Int]
	}
	let session: Session
	let results: [ArrivalResult]
	private(set) var plans: [Plan] = []
	private var memo: [Key: Int] = [:]
	private var components: [Int]
	private var cyclic: Set<Int> = []

	init(session: Session, results: [ArrivalResult]) throws {
		self.session = session
		self.results = results
		components = Array(repeating: -1, count: results.count)
		var reverse: [[Int]] = Array(repeating: [], count: results.count)
		var edges: [[Int]] = []
		for (id, result) in results.enumerated() {
			let children: [Int] = result.families.flatMap(\.children)
			edges.append(children)
			for child: Int in children {
				try session.budget.spend()
				reverse[child].append(id)
			}
		}
		var seen: Set<Int> = []
		var order: [Int] = []
		for root: Int in results.indices where !seen.contains(root) {
			var stack: [(Int, Bool)] = [(root, false)]
			while let (id, finish) = stack.popLast() {
				try session.budget.spend()
				if finish { order.append(id); continue }
				guard seen.insert(id).inserted else { continue }
				stack.append((id, true))
				for child: Int in edges[id].reversed() {
					stack.append((child, false))
				}
			}
		}
		for root: Int in order.reversed() where components[root] == -1 {
			var stack: [Int] = [root]
			var members: [Int] = []
			while let id: Int = stack.popLast() {
				try session.budget.spend()
				guard components[id] == -1 else { continue }
				components[id] = root
				members.append(id)
				stack.append(contentsOf: reverse[id])
			}
			if members.count > 1 || edges[root].contains(root) {
				cyclic.insert(root)
			}
		}
	}

	func build(_ result: Int) throws -> Int {
		let root: Key = .init(result: result, active: [])
		var pending: [Key] = [root]
		while let key: Key = pending.last {
			try session.budget.spend()
			if memo[key] != nil { pending.removeLast(); continue }
			if key.active.contains(key.result) {
				memo[key] = -1
				pending.removeLast()
				continue
			}
			var families: [Branch] = []
			var support: Set<Int> = []
			var hasTrivia: Bool = false
			var missing: Key?
			for family: Family in results[key.result].families {
				var children: [Int] = []
				var valid: Bool = true
				for child: Int in family.children {
					try session.budget.spend()
					let component: Int = components[child]
					let active: Set<Int> = cyclic.contains(component)
						&& component == components[key.result]
						? key.active.union([key.result]) : []
					let childKey: Key = .init(result: child, active: active)
					guard let plan: Int = memo[childKey] else {
						missing = childKey
						break
					}
					if plan == -1 { valid = false; break }
					children.append(plan)
				}
				if missing != nil { break }
				if valid {
					families.append(.init(
						action: family.action,
						children: children,
						trivia: family.trivia
					))
					hasTrivia = hasTrivia || family.trivia != .none
					for child: Int in children {
						hasTrivia = hasTrivia || plans[child].hasTrivia
						for variable: Int in plans[child].support {
							try session.budget.spend()
							support.insert(variable)
						}
					}
				}
			}
			if let missing { pending.append(missing); continue }
			if families.isEmpty { memo[key] = -1 }
			else {
				let id: Int = plans.count
				if families.count > 1 { support.insert(id) }
				plans.append(.init(
					result: key.result,
					families: families,
					support: support,
					hasTrivia: hasTrivia
				))
				memo[key] = id
			}
			pending.removeLast()
		}
		return memo[root]!
	}

	/// 採用した枝を入力順にたどり、確定済みのTrivia列もその位置へつなぐ。
	func collectTrivia(
		from root: Int,
		select: (Int) throws -> TriviaBranch,
	) throws -> Int {
		enum Task {
			case branch(Int)
			case trivia(Int)
		}
		var pending: [Task] = [.branch(root)]
		var trivia: Int = 0

		while let task: Task = pending.popLast() {
			try session.budget.spend()
			switch task {
				case .branch(let id):
					let branch: TriviaBranch = try select(id)
					if case .after(let list) = branch.contribution {
						pending.append(.trivia(list))
					}
					for child: Int in branch.children.reversed() {
						pending.append(.branch(child))
					}
					if case .before(let list) = branch.contribution {
						pending.append(.trivia(list))
					}
				case .trivia(let list):
					trivia = try session.store.triviaLists.joined(trivia, list)
			}
		}

		return trivia
	}
}
