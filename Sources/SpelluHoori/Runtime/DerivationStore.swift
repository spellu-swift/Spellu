import SpelluCore


/// 総作業量の上限。子の確定範囲とも共有する。
struct WorkBudget {

	private var used: Int = 0
	private let limit: Int

	init(
		limit: Int,
	) {
		self.limit = limit
	}

	@inline(__always)
	mutating func spend() throws {
		used += 1

		if used > limit {
			throw SpelluError.safetyStop(
				.other("Hoori work limit exceeded (\(limit))"),
			)
		}
	}

}


/// 前半を共有する不変の列。連結は定数時間で、内容のハッシュを合成して持つ。
/// 辞書で同じ列を一つにまとめず、同値判定はハッシュと内容の比較で行う。
struct RopePool {

	struct Node {
		let left: Int32
		let right: Int32
		let count: Int32
		let first: Int32
		let last: Int32
		let hash: UInt64
		let power: UInt64
	}

	private(set) var nodes: [Node]
	= [
		.init(
			left: -1,
			right: -1,
			count: 0,
			first: -1,
			last: -1,
			hash: 0,
			power: 1,
		),
	]

	mutating func single(
		_ element: Int32,
		hash: UInt64,
	) -> Int32 {
		nodes.append(
			.init(
				left: element,
				right: -1,
				count: 1,
				first: element,
				last: element,
				hash: hash,
				power: 1_000_003,
			),
		)

		return Int32(nodes.count - 1)
	}

	mutating func joined(
		_ left: Int32,
		_ right: Int32,
	) -> Int32 {
		if left == 0 {
			return right
		}

		if right == 0 {
			return left
		}

		let a: Node
		= nodes[Int(left)]

		let b: Node
		= nodes[Int(right)]

		nodes.append(
			.init(
				left: left,
				right: right,
				count: a.count + b.count,
				first: a.first,
				last: b.last,
				hash: a.hash &* b.power &+ b.hash,
				power: a.power &* b.power,
			),
		)

		return Int32(nodes.count - 1)
	}

	/// カーソルを進めて次の要素を返す。`base` より下は他の列の続きなので触らない。
	func next(
		_ cursor: inout [Int32],
		base: Int = 0,
	) -> Int32? {
		while cursor.count > base {
			let id: Int32
			= cursor.removeLast()

			if id == 0 {
				continue
			}

			let node: Node
			= nodes[Int(id)]

			if node.right < 0 {
				return node.left
			}

			cursor.append(node.right)
			cursor.append(node.left)
		}

		return nil
	}

	func values(
		_ id: Int32,
	) -> [Int32] {
		var result: [Int32] = []
		var cursor: [Int32] = [id]

		while let value: Int32 = next(&cursor) {
			result.append(value)
		}

		return result
	}

	@inline(__always)
	func signatureEqual(
		_ left: Int32,
		_ right: Int32,
	) -> Bool {
		let a: Node
		= nodes[Int(left)]

		let b: Node
		= nodes[Int(right)]

		return a.count == b.count && a.hash == b.hash
	}

}


/// 導出の候補。木・Atom・選択履歴を列で持ち、順位は比較範囲を閉じるまで足す。
struct Candidate {
	var trees: Int32 = 0
	var atoms: Int32 = 0
	var selections: Int32 = 0
	var rank: Int32 = 0
	var history: Int32 = -1
	/// 自動Triviaで読み飛ばした範囲の列。順位の比較には使わず、等しさには含める。
	var trivia: Int32 = 0
}


/// 候補を構成する木・選択履歴・反復履歴の保存領域。一回の解析の間だけ生存する。
struct DerivationStore {

	struct Tree {
		let grammar: Int32
		let label: Int32
		let begin: Int32
		let end: Int32
		let children: Int32
		let hash: UInt64
	}

	struct Selection {
		let scope: Int32
		let atoms: Int32
		let rank: Int32
		let children: Int32
		let hash: UInt64
	}

	/// 自動Triviaで読み飛ばした範囲。読み飛ばしを求めた文法と、絶対UTF-8範囲。
	struct TriviaSpan : Equatable {
		let grammar: Int32
		let begin: Int32
		let end: Int32
		/// 直前の範囲と同じ読み飛ばしの続きなら `true`。
		let continuing: Bool
	}

	struct Iteration {
		let previous: Int32
		let control: Int32
		let rank: Int32
		let body: Candidate
		/// 先頭の回から数えた回数。
		let depth: Int32
	}

	enum Ordering {
		case better
		case worse
		case same
		case unordered
	}

	var budget: WorkBudget
	private(set) var treeLists: RopePool = .init()
	private(set) var atomLists: RopePool = .init()
	private(set) var selectionLists: RopePool = .init()
	private(set) var triviaLists: RopePool = .init()
	private(set) var triviaSpans: [TriviaSpan] = []
	private(set) var trees: [Tree] = []
	private(set) var selections: [Selection] = []
	private(set) var iterations: [Iteration] = []
	private var leafSelection: Int32 = 0

	// 比較のたびに配列を確保しないよう、作業領域を使い回す。
	private var compareLeft: [Int32] = []
	private var compareRight: [Int32] = []
	private var compareFrames: [(left: Int, right: Int)] = []
	private var atomLeft: [Int32] = []
	private var atomRight: [Int32] = []

	init(
		budget: WorkBudget,
	) {
		self.budget = budget

		// 字句など、範囲を持たない子の選択履歴。
		selections.append(
			.init(
				scope: -1,
				atoms: 0,
				rank: 0,
				children: 0,
				hash: 0,
			),
		)
		leafSelection = selectionLists.single(0, hash: 0)
	}

	@inline(__always)
	private static func mix(
		_ seed: UInt64,
		_ value: UInt64,
	) -> UInt64 {
		let mixed: UInt64
		= (seed ^ value) &* 0x9E37_79B9_7F4A_7C15

		return mixed ^ (mixed >> 29)
	}

	// MARK: 木

	mutating func tree(
		grammar: Int32,
		label: Int32,
		begin: Int32,
		end: Int32,
		children: Int32 = 0,
	) -> Int32 {
		var hash: UInt64 = 0

		hash = Self.mix(hash, UInt64(UInt32(bitPattern: grammar)))
		hash = Self.mix(hash, UInt64(UInt32(bitPattern: label)))
		hash = Self.mix(hash, UInt64(UInt32(bitPattern: begin)))
		hash = Self.mix(hash, UInt64(UInt32(bitPattern: end)))
		hash = Self.mix(hash, treeLists.nodes[Int(children)].hash)

		trees.append(
			.init(
				grammar: grammar,
				label: label,
				begin: begin,
				end: end,
				children: children,
				hash: hash,
			),
		)

		return treeLists.single(Int32(trees.count - 1), hash: hash)
	}

	/// 子の先頭と末尾から範囲を求める。子がなければ終了位置の空範囲にする。
	mutating func branch(
		grammar: Int32,
		label: Int32,
		children: Int32,
		cursor: Int32,
	) -> Int32 {
		let node: RopePool.Node
		= treeLists.nodes[Int(children)]

		return tree(
			grammar: grammar,
			label: label,
			begin: node.first < 0 ? cursor : trees[Int(node.first)].begin,
			end: node.last < 0 ? cursor : trees[Int(node.last)].end,
			children: children,
		)
	}

	/// 返された最上位の木だけラベルを変える。子孫はそのまま共有する。
	mutating func relabeled(
		_ list: Int32,
		label: Int32,
	) -> Int32 {
		var output: Int32 = 0

		for id: Int32 in treeLists.values(list) {
			let old: Tree
			= trees[Int(id)]

			output = treeLists.joined(
				output,
				tree(
					grammar: old.grammar,
					label: label,
					begin: old.begin,
					end: old.end,
					children: old.children,
				),
			)
		}

		return output
	}

	// MARK: 候補

	mutating func leaf(
		trees list: Int32,
		atom: Int32,
		trivia: Int32 = 0,
	) -> Candidate {
		.init(
			trees: list,
			atoms: atomLists.single(atom, hash: Self.mix(1, UInt64(atom))),
			selections: leafSelection,
			trivia: trivia,
		)
	}

	/// 読み飛ばした範囲を一つだけ持つ列を作る。
	mutating func triviaList(
		grammar: Int32,
		begin: Int32,
		end: Int32,
		continuing: Bool,
	) -> Int32 {
		var hash: UInt64
		= Self.mix(3, UInt64(UInt32(bitPattern: grammar)))

		hash = Self.mix(hash, UInt64(UInt32(bitPattern: begin)))
		hash = Self.mix(hash, UInt64(UInt32(bitPattern: end)))

		triviaSpans.append(
			.init(
				grammar: grammar,
				begin: begin,
				end: end,
				continuing: continuing,
			),
		)

		return triviaLists.single(Int32(triviaSpans.count - 1), hash: hash)
	}

	mutating func joinedTrivia(
		_ left: Int32,
		_ right: Int32,
	) -> Int32 {
		triviaLists.joined(left, right)
	}

	/// 自動Triviaの列を入力の順に取り出す。
	func spans(
		_ list: Int32,
	) -> [TriviaSpan] {
		triviaLists.values(list).map { triviaSpans[Int($0)] }
	}

	mutating func joined(
		_ left: Candidate,
		_ right: Candidate,
	) -> Candidate {
		.init(
			trees: treeLists.joined(left.trees, right.trees),
			atoms: atomLists.joined(left.atoms, right.atoms),
			selections: selectionLists.joined(
				left.selections,
				right.selections,
			),
			rank: left.rank + right.rank,
			trivia: triviaLists.joined(left.trivia, right.trivia),
		)
	}

	/// 比較範囲を閉じる。内部の順位とAtomは選択履歴へ移り、外へは範囲の識別だけが見える。
	mutating func enclosed(
		_ value: Candidate,
		scope: Int32,
		rank: Int32? = nil,
	) -> Candidate {
		let resolved: Int32
		= rank ?? value.rank

		var hash: UInt64
		= Self.mix(2, UInt64(UInt32(bitPattern: scope)))

		hash = Self.mix(hash, atomLists.nodes[Int(value.atoms)].hash)
		hash = Self.mix(hash, UInt64(UInt32(bitPattern: resolved)))
		hash = Self.mix(hash, selectionLists.nodes[Int(value.selections)].hash)

		selections.append(
			.init(
				scope: scope,
				atoms: value.atoms,
				rank: resolved,
				children: value.selections,
				hash: hash,
			),
		)

		return .init(
			trees: value.trees,
			atoms: atomLists.single(scope, hash: Self.mix(1, UInt64(scope))),
			selections: selectionLists.single(
				Int32(selections.count - 1),
				hash: hash,
			),
			trivia: value.trivia,
		)
	}

	mutating func iteration(
		previous: Int32,
		control: Int32,
		rank: Int32,
		body: Candidate,
	) -> Int32 {
		iterations.append(
			.init(
				previous: previous,
				control: control,
				rank: rank,
				body: body,
				depth: previous < 0 ? 1 : iterations[Int(previous)].depth + 1,
			),
		)

		return Int32(iterations.count - 1)
	}

	/// 反復の各回を先頭の回からの入れ子に組み立てる。
	mutating func finish(
		_ history: Int32,
		ending: Candidate,
	) throws -> Candidate {
		var result: Candidate
		= ending

		var cursor: Int32
		= history

		while cursor >= 0 {
			try budget.spend()

			let item: Iteration
			= iterations[Int(cursor)]

			result = enclosed(
				joined(item.body, result),
				scope: item.control,
				rank: item.rank,
			)
			cursor = item.previous
		}

		return result
	}

	func priority(
		_ value: Candidate,
	) -> Int {
		let first: Int32
		= selectionLists.nodes[Int(value.selections)].first

		return first < 0 ? 0 : Int(selections[Int(first)].rank)
	}

	// MARK: 比較

	/// 選択履歴を左から比べ、最初に差が付いた箇所で優劣を決める。
	mutating func compare(
		_ left: Int32,
		_ right: Int32,
	) throws -> Ordering {
		if left == right {
			return .same
		}

		guard
			selectionLists.nodes[Int(left)].count
				== selectionLists.nodes[Int(right)].count
		else { return .unordered }

		compareLeft.removeAll(keepingCapacity: true)
		compareRight.removeAll(keepingCapacity: true)
		compareFrames.removeAll(keepingCapacity: true)

		compareFrames.append((0, 0))
		compareLeft.append(left)
		compareRight.append(right)

		while let frame: (left: Int, right: Int) = compareFrames.last {
			try budget.spend()

			let lid: Int32?
			= selectionLists.next(&compareLeft, base: frame.left)

			let rid: Int32?
			= selectionLists.next(&compareRight, base: frame.right)

			guard
				let lid,
				let rid
			else {
				compareFrames.removeLast()

				continue
			}

			if lid == rid {
				continue
			}

			let a: Selection
			= selections[Int(lid)]

			let b: Selection
			= selections[Int(rid)]

			guard
				a.scope == b.scope
			else { return .unordered }

			if try !atomsEqual(a.atoms, b.atoms) || a.rank != b.rank {
				if a.rank > b.rank {
					return .better
				}

				if a.rank < b.rank {
					return .worse
				}

				return .unordered
			}

			if a.children != b.children {
				guard
					selectionLists.nodes[Int(a.children)].count
						== selectionLists.nodes[Int(b.children)].count
				else { return .unordered }

				compareFrames.append((compareLeft.count, compareRight.count))
				compareLeft.append(a.children)
				compareRight.append(b.children)
			}
		}

		return .same
	}

	/// 同じ到達へ至る反復の前半同士を、先頭の回から比べる。
	/// 共有している前半は飛ばす。比べた範囲に差がなければ、残りの回では決められない。
	mutating func compareHistories(
		_ left: Int32,
		_ right: Int32,
	) throws -> Ordering {
		var a: Int32 = left
		var b: Int32 = right
		var lc: [Int32] = []
		var rc: [Int32] = []

		while a != b {
			try budget.spend()

			let da: Int32
			= a < 0 ? 0 : iterations[Int(a)].depth

			let db: Int32
			= b < 0 ? 0 : iterations[Int(b)].depth

			if da >= db {
				lc.append(a)
				a = iterations[Int(a)].previous
			}

			if db >= da {
				rc.append(b)
				b = iterations[Int(b)].previous
			}
		}

		while let x: Int32 = lc.popLast(), let y: Int32 = rc.popLast() {
			let p: Iteration
			= iterations[Int(x)]

			let q: Iteration
			= iterations[Int(y)]

			guard
				p.control == q.control
			else { return .unordered }

			if p.rank != q.rank {
				return p.rank > q.rank ? .better : .worse
			}

			let order: Ordering
			= try compare(p.body.selections, q.body.selections)

			guard
				order == .same
			else { return order }

			guard
				try equal(p.body, q.body)
			else { return .unordered }
		}

		return lc.isEmpty && rc.isEmpty ? .same : .unordered
	}

	private mutating func atomsEqual(
		_ left: Int32,
		_ right: Int32,
	) throws -> Bool {
		if left == right {
			return true
		}

		guard
			atomLists.signatureEqual(left, right)
		else { return false }

		atomLeft.removeAll(keepingCapacity: true)
		atomRight.removeAll(keepingCapacity: true)
		atomLeft.append(left)
		atomRight.append(right)

		while true {
			try budget.spend()

			let a: Int32?
			= atomLists.next(&atomLeft, base: 0)

			let b: Int32?
			= atomLists.next(&atomRight, base: 0)

			if a != b {
				return false
			}

			if a == nil {
				return true
			}
		}
	}

	/// 候補の完全な同値判定。木・Atom・順位・選択履歴・反復履歴がすべて同じなら同じ候補。
	mutating func equal(
		_ left: Candidate,
		_ right: Candidate,
	) throws -> Bool {
		if left.trees == right.trees,
			left.atoms == right.atoms,
			left.selections == right.selections,
			left.rank == right.rank,
			left.history == right.history,
			left.trivia == right.trivia
		{
			return true
		}

		guard
			left.rank == right.rank,
			left.history == right.history,
			treeLists.signatureEqual(left.trees, right.trees),
			atomLists.signatureEqual(left.atoms, right.atoms),
			selectionLists.signatureEqual(left.selections, right.selections),
			triviaLists.signatureEqual(left.trivia, right.trivia),
			spans(left.trivia) == spans(right.trivia),
			try atomsEqual(left.atoms, right.atoms),
			try treesEqual(left.trees, right.trees)
		else { return false }

		return try compare(left.selections, right.selections) == .same
	}

	private mutating func treesEqual(
		_ left: Int32,
		_ right: Int32,
	) throws -> Bool {
		var pending: [(Int32, Int32)]
		= [(left, right)]

		while let (lid, rid): (Int32, Int32) = pending.popLast() {
			try budget.spend()

			if lid == rid {
				continue
			}

			guard
				treeLists.signatureEqual(lid, rid)
			else { return false }

			let a: [Int32]
			= treeLists.values(lid)

			let b: [Int32]
			= treeLists.values(rid)

			guard
				a.count == b.count
			else { return false }

			for (x, y) in zip(a, b) where x != y {
				let p: Tree
				= trees[Int(x)]

				let q: Tree
				= trees[Int(y)]

				guard
					p.grammar == q.grammar,
					p.label == q.label,
					p.begin == q.begin,
					p.end == q.end
				else { return false }

				pending.append((p.children, q.children))
			}
		}

		return true
	}

}
