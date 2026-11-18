import SpelluCore


///
/// 選んだ木をSourceNodeにする
///
/// 木の深さでSwiftの呼び出しが深くならないよう、`Walk` でたどる。
///
struct TreeBuilder {

	/// 木の列をSourceNodeの列にする。
	///
	/// `.compact` では、同じ文法の一時ラベル（`#…` とラベルなし）のノードを畳み込む。
	func build(
		_ roots: ListID<TreeID>,
		strategy: TreeStrategy,
		_ session: inout Session,
	) throws -> [SourceNode] {
		let store: Store
		= session.store

		var walk: Walk<TreeID, SourceNode>
		= .init()

		var output: [SourceNode] = []

		for root: TreeID in store.treeLists.elements(roots) {
			let node: SourceNode
			= try walk.value(
				of: root,
				children: { tree in
					store.treeLists.elements(store[tree].children)
				},
				combine: { tree, parts in
					try session.spend()

					return Self.node(
						store[tree],
						parts: parts,
						strategy: strategy,
						session,
					)
				},
				cut: { _ in
					throw SpelluError.internalError("Tree must not be cyclic")
				},
			)

			output.append(node)
		}

		return output
	}

	private static func node(
		_ tree: Store.Tree,
		parts: [SourceNode],
		strategy: TreeStrategy,
		_ session: Session,
	) -> SourceNode {
		let grammar: String
		= session.table[tree.grammar].name

		var children: [SourceNode]
		= parts

		if strategy == .compact {
			children = []

			var pending: [SourceNode]
			= parts.reversed()

			while let child: SourceNode = pending.popLast() {
				if child.grammar == grammar && child.label.isTemporary {
					pending.append(contentsOf: child.parts.reversed())
				}
				else {
					children.append(child)
				}
			}
		}

		return .init(
			grammar: grammar,
			label: tree.label,
			source: session.source,
			begin: tree.begin,
			end: tree.end,
			parts: children,
		)
	}

}
