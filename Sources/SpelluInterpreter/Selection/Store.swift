import SpelluCore


/// 木の番号。
struct TreeID : Hashable, Sendable {
	let rawValue: Int
}


/// 列の番号。`Element` は列の要素の型。
struct ListID<Element> : Hashable, Sendable {
	let rawValue: Int

	/// 空の列。
	static var empty: Self {
		.init(rawValue: 0)
	}
}


///
/// 列のストア
///
/// 列は「前の列の末尾に要素を一つ足した節」の連なりで表す。
/// 同じ節には同じ番号を振るので、内容が同じ列は同じ番号になり、等しいかどうかは番号で分かる。
/// 列を伸ばすときに要素をコピーしないので、長い反復でも費用が回数の2乗にならない。
///
struct ListStore<Element : Hashable> {

	private struct Node : Hashable {
		let prefix: ListID<Element>
		let element: Element
	}

	/// 空の列の番号0には節がないので、添字は1つずらして使う。
	private var nodes: [Node] = []
	private var firsts: [Element] = []
	private var counts: [Int] = []
	private var ids: [Node: ListID<Element>] = [:]

	init() {
	}

	/// 要素一つの列。
	mutating func single(
		_ element: Element,
	) -> ListID<Element> {
		appending(element, to: .empty)
	}

	/// 列の末尾に要素を一つ足した列。
	mutating func appending(
		_ element: Element,
		to list: ListID<Element>,
	) -> ListID<Element> {
		let node: Node
		= .init(prefix: list, element: element)

		if let id: ListID<Element> = ids[node] {
			return id
		}

		let id: ListID<Element>
		= .init(rawValue: nodes.count + 1)

		nodes.append(node)
		firsts.append(first(list) ?? element)
		counts.append(count(list) + 1)
		ids[node] = id

		return id
	}

	/// 2つの列をつないだ列。右の列の要素の数だけ節を足す。
	mutating func concat(
		_ left: ListID<Element>,
		_ right: ListID<Element>,
	) -> ListID<Element> {
		var result: ListID<Element>
		= left

		for element: Element in elements(right) {
			result = appending(element, to: result)
		}

		return result
	}

	/// 要素の数。
	func count(
		_ list: ListID<Element>,
	) -> Int {
		list == .empty ? 0 : counts[list.rawValue - 1]
	}

	/// 最初の要素。
	func first(
		_ list: ListID<Element>,
	) -> Element? {
		list == .empty ? nil : firsts[list.rawValue - 1]
	}

	/// 最後の要素。
	func last(
		_ list: ListID<Element>,
	) -> Element? {
		list == .empty ? nil : nodes[list.rawValue - 1].element
	}

	/// すべての要素を左から順に並べる。
	func elements(
		_ list: ListID<Element>,
	) -> [Element] {
		var output: [Element] = []
		var cursor: ListID<Element>
		= list

		output.reserveCapacity(count(list))

		while cursor != .empty {
			let node: Node
			= nodes[cursor.rawValue - 1]

			output.append(node.element)
			cursor = node.prefix
		}

		return output.reversed()
	}

}


///
/// 木のストア
///
/// 木は配列に入れて番号で参照する。同じ形の木には同じ番号を振るので、
/// 等しいかどうかは番号で分かる。値の中に参照の長い連鎖がないので、
/// 比較・ハッシュ・解放でSwiftの呼び出しが深くならない。
///
struct Store {

	/// まだSourceNodeにしていない木。
	struct Tree : Hashable {
		let grammar: GrammarID
		let label: Label
		let begin: Int
		let end: Int
		let children: ListID<TreeID>
	}

	private var trees: [Tree] = []
	private var treeIDs: [Tree: TreeID] = [:]
	private var selections: [Selection] = []
	private var selectionIDs: [Selection: SelectionID] = [:]
	private var iterations: [Iteration] = []
	private var iterationIDs: [Iteration: IterationID] = [:]

	/// 木の列。
	var treeLists: ListStore<TreeID> = .init()

	/// Atomの列。
	var atomLists: ListStore<Atom> = .init()

	/// 選択履歴の列。
	var selectionLists: ListStore<SelectionID> = .init()

	/// 自動Triviaの列。
	var triviaLists: ListStore<TriviaSpan> = .init()

	/// 葉（範囲を持たない子）の選択履歴だけを持つ列。
	private(set) var leafSelections: ListID<SelectionID> = .empty

	init() {
		let leaf: SelectionID
		= selection(
			.init(
				scope: .leaf,
				atoms: .empty,
				rank: 0,
				children: .empty,
			),
		)

		leafSelections = selectionLists.single(leaf)
	}

	subscript(
		tree: TreeID,
	) -> Tree {
		trees[tree.rawValue]
	}

	subscript(
		selection: SelectionID,
	) -> Selection {
		selections[selection.rawValue]
	}

	subscript(
		iteration: IterationID,
	) -> Iteration {
		iterations[iteration.rawValue]
	}

	/// 反復の履歴の番号。同じ内容の履歴には同じ番号を振る。
	mutating func iteration(
		_ value: Iteration,
	) -> IterationID {
		if let id: IterationID = iterationIDs[value] {
			return id
		}

		let id: IterationID
		= .init(rawValue: iterations.count)

		iterations.append(value)
		iterationIDs[value] = id

		return id
	}

	/// 反復の履歴を、最初の回から順に並べる。
	func chain(
		_ last: IterationID?,
	) -> [IterationID] {
		var output: [IterationID] = []
		var cursor: IterationID? = last

		while let id: IterationID = cursor {
			output.append(id)
			cursor = self[id].previous
		}

		return output.reversed()
	}

	/// 選択履歴の番号。同じ内容の選択履歴には同じ番号を振る。
	mutating func selection(
		_ value: Selection,
	) -> SelectionID {
		if let id: SelectionID = selectionIDs[value] {
			return id
		}

		let id: SelectionID
		= .init(rawValue: selections.count)

		selections.append(value)
		selectionIDs[value] = id

		return id
	}

	/// 字句などの葉。
	mutating func leaf(
		grammar: GrammarID,
		label: Label,
		begin: Int,
		end: Int,
	) -> TreeID {
		tree(
			.init(
				grammar: grammar,
				label: label,
				begin: begin,
				end: end,
				children: .empty,
			),
		)
	}

	/// 子を持つ枝。範囲は最初の子から最後の子まで。子がなければ `cursor` の点。
	mutating func branch(
		grammar: GrammarID,
		label: Label,
		children: ListID<TreeID>,
		cursor: Int,
	) -> TreeID {
		let begin: Int
		= treeLists.first(children).map { self[$0].begin } ?? cursor

		let end: Int
		= treeLists.last(children).map { self[$0].end } ?? cursor

		return tree(
			.init(
				grammar: grammar,
				label: label,
				begin: begin,
				end: end,
				children: children,
			),
		)
	}

	/// 列の各木のラベルを付け替えた列。子はそのまま。
	mutating func relabeled(
		_ list: ListID<TreeID>,
		label: Label,
	) -> ListID<TreeID> {
		var output: ListID<TreeID>
		= .empty

		for id: TreeID in treeLists.elements(list) {
			let old: Tree
			= self[id]

			let tree: TreeID
			= tree(
				.init(
					grammar: old.grammar,
					label: label,
					begin: old.begin,
					end: old.end,
					children: old.children,
				),
			)

			output = treeLists.appending(tree, to: output)
		}

		return output
	}

	private mutating func tree(
		_ value: Tree,
	) -> TreeID {
		if let id: TreeID = treeIDs[value] {
			return id
		}

		let id: TreeID
		= .init(rawValue: trees.count)

		trees.append(value)
		treeIDs[value] = id

		return id
	}

}
