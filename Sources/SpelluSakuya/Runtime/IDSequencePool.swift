import SpelluCore

/// 列の分割方法に依存しない内容ハッシュで、同じ列を共有する。
final class IDSequencePool {

	private enum Contents {
		case empty
		case element(Int)
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
		let first: Int?
		let last: Int?
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
	private var buckets: [Signature: [Int]] = [:]

	init(_ budget: WorkBudget) { self.budget = budget }

	// 非負の正規化済みIDは、負の列IDへ直接埋め込む。
	func single(_ value: Int) throws -> Int {
		precondition(value >= 0)
		return ~value
	}

	private func node(_ id: Int) -> Node {
		if id >= 0 {
			return nodes[id]
		}
		let value: Int = ~id
		return .init(
			contents: .element(value),
			signature: .init(
				count: 1,
				hash: UInt64(bitPattern: Int64(value.hashValue))
			),
			power: 1_000_003,
			first: value,
			last: value
		)
	}

	func joined(_ left: Int, _ right: Int) throws -> Int {
		if left == 0 {
			return right
		}
		if right == 0 {
			return left
		}
		try budget.spend()
		let a: Node = node(left)
		let b: Node = node(right)
		let signature: Signature = .init(
			count: a.signature.count + b.signature.count,
			hash: a.signature.hash &* b.power &+ b.signature.hash
		)
		for existing: Int in buckets[signature] ?? [] {
			if case .joined(let a, let b) = node(existing).contents,
				a == left, b == right
			{
				return existing
			}
			var source: [Int] = [right, left]
			var target: [Int] = [existing]
			var equal: Bool = true
			while let value: Int = try next(&source) {
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

	func next(_ cursor: inout [Int]) throws -> Int? {
		while let id: Int = cursor.popLast() {
			try budget.spend()
			switch node(id).contents {
				case .empty: continue
				case .element(let value): return value
				case .joined(let left, let right):
					cursor.append(right)
					cursor.append(left)
			}
		}
		return nil
	}

	func values(_ id: Int) throws -> [Int] {
		var result: [Int] = []
		var cursor: [Int] = [id]
		while let value: Int = try next(&cursor) { result.append(value) }
		return result
	}

	func count(_ id: Int) -> Int { id < 0 ? 1 : nodes[id].signature.count }

	func first(_ id: Int) -> Int? { id < 0 ? ~id : nodes[id].first }
	func last(_ id: Int) -> Int? { id < 0 ? ~id : nodes[id].last }
}
