import SpelluCore


extension Chart {

	/// 出口の記号ノードから導出を選ぶ。候補がなければnilを返す。
	func select(
		_ session: inout Session,
	) throws -> Match? {
		var resolver: Resolver
		= .init(chart: self)

		return try resolver.select(&session)
	}

}


/// 森から候補を解決し、順位規則で一件を選ぶ。
///
/// 探索が終わってから動くので、導出はもう増えない。
/// 森全体に導出が一つしかなければ、木だけを組み立てる。
private struct Resolver {

	/// skipの記号ノードごとの、採用した読み方。構文Triviaを読むときにだけ確保する。
	private var triviaSteps: [TriviaStep] = []

	/// 候補の保存領域の範囲。
	private struct Values {
		var start: Int32
		var count: Int32

		static let unresolved: Self = .init(start: -1, count: 0)
		static let none: Self = .init(start: 0, count: 0)
		/// 空の候補一件。保存領域の先頭に置く。
		static let empty: Self = .init(start: 0, count: 1)

		var isResolved: Bool {
			start >= 0
		}
	}

	/// skipの読み方の、最後の構文Trivia。
	private struct TriviaStep {
		/// 一つ前のskipの記号ノード。構文Triviaを読まない導出なら-1。
		var parent: Int32 = -1
		/// 読んだ構文Triviaの個数。
		var depth: Int32 = 0
		var begin: Int32 = -1
		var end: Int32 = -1
		/// 先頭からここまでの範囲の列を持つ候補。
		var values: Values = .unresolved
	}

	private struct Frame {
		let isNode: Bool
		let target: Int32
		/// 囲んでいるルール呼び出し。ルールの外なら-1。
		let context: Int32
		/// 次に調べる家族またはリンク。-2は一件目、-1は終わり。
		var cursor: Int32 = -2
		var stage: Stage = .next
		var link: (left: Int32, right: Int32) = (-1, -1)
		var left: Values = .none
		var right: Values = .none
		var first: Candidate? = nil
		var rest: [Candidate] = []
		var cyclic: Bool = false

		init(
			isNode: Bool,
			target: Int32,
			context: Int32,
		) {
			self.isNode = isNode
			self.target = target
			self.context = context
		}
	}

	private enum Stage {
		case next
		case awaitingLeft
		case right
		case awaitingRight
		case product
		case awaitingFamily
	}

	private let chart: Chart
	private var detail: Bool = true
	private var values: [Candidate] = [.init()]
	private var nodeMemo: [Values]
	private var itemMemo: [Values]
	private var nodeMemoContext: [Int32]
	private var itemMemoContext: [Int32]
	/// 解決中のノードの文脈。一つのノードが複数の文脈で解決中なら残りは集合へ置く。
	private var activeContext: [Int32]
	private var activeOverflow: Set<UInt64> = []
	private var frames: [Frame] = []

	init(
		chart: Chart,
	) {
		self.chart = chart
		self.nodeMemo = .init(
			repeating: .unresolved,
			count: chart.nodes.count,
		)
		self.itemMemo = .init(
			repeating: .unresolved,
			count: chart.items.count,
		)
		self.nodeMemoContext = .init(
			repeating: -1,
			count: chart.nodes.count,
		)
		self.itemMemoContext = .init(
			repeating: -1,
			count: chart.items.count,
		)
		self.activeContext = .init(
			repeating: -2,
			count: chart.nodes.count,
		)
	}

	// MARK: 選択

	mutating func select(
		_ session: inout Session,
	) throws -> Match? {
		var roots: [Int32] = []

		if let entry: Chart.Call = chart.calls.first {
			var node: Int32
			= entry.lastNode

			while node >= 0 {
				roots.append(node)
				node = chart.nodes[Int(node)].previous
			}

			roots.reverse()
		}

		guard
			!roots.isEmpty
		else { return nil }

		detail = !(roots.count == 1 && isPlain(roots[0], &session))

		var frontier: [(value: Candidate, node: Int32)] = []

		for root: Int32 in roots {
			let resolved: Values
			= try resolve(root, &session)

			for offset: Int32 in 0..<resolved.count {
				let value: Candidate
				= self.values[Int(resolved.start + offset)]

				try add(value, root, to: &frontier, &session)
			}
		}

		guard
			let winner: (value: Candidate, node: Int32) = frontier.first
		else { return nil }

		guard
			frontier.count == 1
		else {
			throw SpelluError.ambiguousPath(
				precedence: session.store.priority(winner.value),
			)
		}

		let node: Chart.Node
		= chart.nodes[Int(winner.node)]

		return .init(
			end: node.end,
			environment: node.environment,
			trees: winner.value.trees,
			trivia: winner.value.trivia,
		)
	}

	/// 劣る候補を捨て、優る候補に負ける既存の候補を除く。
	private mutating func add(
		_ value: Candidate,
		_ node: Int32,
		to frontier: inout [(value: Candidate, node: Int32)],
		_ session: inout Session,
	) throws {
		guard
			detail
		else {
			frontier.append((value, node))

			return
		}

		var removed: [Int] = []

		for index: Int in frontier.indices {
			switch try session.store.compare(
				value.selections,
				frontier[index].value.selections,
			) {
				case .worse:
					return
				case .better:
					removed.append(index)
				case .same, .unordered:
					break
			}
		}

		for index: Int in removed.reversed() {
			frontier.remove(at: index)
		}

		frontier.append((value, node))
	}

	/// 出口から到達できる森に、導出が一つしかないかを調べる。
	private func isPlain(
		_ root: Int32,
		_ session: inout Session,
	) -> Bool {
		var visited: [Bool]
		= .init(repeating: false, count: chart.nodes.count)

		var stack: [Int32]
		= [root]

		while let id: Int32 = stack.popLast() {
			if visited[Int(id)] {
				continue
			}

			visited[Int(id)] = true

			let node: Chart.Node
			= chart.nodes[Int(id)]

			let kind: GrammarModel.NonterminalKind
			= session.model.nonterminals[
				Int(chart.calls[Int(node.call)].nonterminal)
			].kind

			if case .explicitTrivia = kind {
				continue
			}

			if node.more >= 0 {
				return false
			}

			var item: Chart.Item
			= chart.items[Int(node.family)]

			while item.left >= 0 {
				if item.more >= 0 {
					return false
				}

				if case let .nonterminal(nonterminal, _)
					= session.model.symbols[Int(item.dot) - 1]
				{
					if case .skip
						= session.model.nonterminals[Int(nonterminal)].kind
					{
					}
					else {
						stack.append(item.right)
					}
				}

				item = chart.items[Int(item.left)]
			}
		}

		return true
	}

	// MARK: 解決

	/// 森を明示スタックでたどる。現在の経路へ戻る枝は打ち切り、
	/// 打ち切りを含む結果は経路に依存するので共有しない。
	///
	/// 補助の非終端の解決は、囲んでいるルール呼び出しごとに別のものとして扱う。
	/// 同じルール呼び出しの中で同じノードへ戻ったときだけ、循環として打ち切る。
	private mutating func resolve(
		_ root: Int32,
		_ session: inout Session,
	) throws -> Values {
		if let known: Values = knownNode(root, context: -1, &session) {
			return known
		}

		pushNode(root, parentContext: -1, &session)

		var returned: Values = .none

		while let top: Int = frames.indices.last {
			try session.store.budget.spend()

			if frames[top].isNode {
				try stepNode(top, &returned, &session)
			}
			else {
				try stepItem(top, &returned, &session)
			}
		}

		return returned
	}

	@inline(__always)
	private func isRule(
		_ node: Int32,
		_ session: inout Session,
	) -> Bool {
		session.model.nonterminals[
			Int(chart.calls[Int(chart.nodes[Int(node)].call)].nonterminal)
		].isRule
	}

	/// ルールのノードの文脈は自身の呼び出し、それ以外は外側の文脈を引き継ぐ。
	@inline(__always)
	private func context(
		of node: Int32,
		parentContext: Int32,
		_ session: inout Session,
	) -> Int32 {
		isRule(node, &session) ? chart.nodes[Int(node)].call : parentContext
	}

	private func knownNode(
		_ node: Int32,
		context parent: Int32,
		_ session: inout Session,
	) -> Values? {
		guard
			nodeMemo[Int(node)].isResolved
		else { return nil }

		if isRule(node, &session) || nodeMemoContext[Int(node)] == parent {
			return nodeMemo[Int(node)]
		}

		return nil
	}

	private func knownItem(
		_ item: Int32,
		context: Int32,
	) -> Values? {
		guard
			itemMemo[Int(item)].isResolved,
			itemMemoContext[Int(item)] == context
		else { return nil }

		return itemMemo[Int(item)]
	}

	private func overflowKey(
		_ node: Int32,
		_ context: Int32,
	) -> UInt64 {
		UInt64(UInt32(bitPattern: node)) << 32
			| UInt64(UInt32(bitPattern: context))
	}

	/// 反復の前半は必ず短い範囲へ進むので、循環は本文かルールで検出する。
	/// 前半を回数ごとに分けていないので、ここで打ち切ると別の回数の前半まで切ってしまう。
	private func tracksCycle(
		_ node: Int32,
		_ session: inout Session,
	) -> Bool {
		if case .loopPrefix = session.model.nonterminals[
			Int(chart.calls[Int(chart.nodes[Int(node)].call)].nonterminal)
		].kind {
			return false
		}

		return true
	}

	private func isActive(
		_ node: Int32,
		context: Int32,
	) -> Bool {
		activeContext[Int(node)] == context
			|| (
				!activeOverflow.isEmpty
					&& activeOverflow.contains(overflowKey(node, context))
			)
	}

	private mutating func pushNode(
		_ node: Int32,
		parentContext: Int32,
		_ session: inout Session,
	) {
		let context: Int32
		= context(of: node, parentContext: parentContext, &session)

		if tracksCycle(node, &session) {
			if activeContext[Int(node)] == -2 {
				activeContext[Int(node)] = context
			}
			else {
				activeOverflow.insert(overflowKey(node, context))
			}
		}

		frames.append(.init(isNode: true, target: node, context: context))
	}

	private mutating func popActive(
		_ node: Int32,
		context: Int32,
	) {
		if activeContext[Int(node)] == context {
			activeContext[Int(node)] = -2
		}
		else {
			activeOverflow.remove(overflowKey(node, context))
		}
	}

	private mutating func finishFrame(
		_ returned: inout Values,
	) {
		let frame: Frame
		= frames.removeLast()

		let start: Int32
		= Int32(values.count)

		if let first: Candidate = frame.first {
			values.append(first)
			values.append(contentsOf: frame.rest)
		}

		returned = .init(
			start: start,
			count: Int32(values.count) - start,
		)

		if frame.isNode {
			popActive(frame.target, context: frame.context)
		}

		if frame.cyclic {
			if let parent: Int = frames.indices.last {
				frames[parent].cyclic = true
			}
		}
		else if frame.isNode {
			nodeMemo[Int(frame.target)] = returned
			nodeMemoContext[Int(frame.target)] = frame.context
		}
		else {
			itemMemo[Int(frame.target)] = returned
			itemMemoContext[Int(frame.target)] = frame.context
		}
	}

	private mutating func addCandidate(
		_ value: Candidate,
		to top: Int,
		_ session: inout Session,
	) throws {
		guard
			let first: Candidate = frames[top].first
		else {
			frames[top].first = value

			return
		}

		try session.store.budget.spend()

		if try session.store.equal(first, value) {
			return
		}

		for existing: Candidate in frames[top].rest {
			try session.store.budget.spend()

			if try session.store.equal(existing, value) {
				return
			}
		}

		frames[top].rest.append(value)
	}

	/// 同じ到達の候補のうち、厳密に劣るものを捨てる。
	///
	/// 比較範囲を閉じた候補の後続は、到達だけで決まる。比較は最初の差で決まるので、
	/// 劣る候補を使う導出は、優る候補へ置き換えた導出に必ず負ける。
	/// 同値と比較不能は親の比較で消える場合があるので残す。
	private mutating func addCompeting(
		_ value: Candidate,
		to top: Int,
		history: Bool,
		_ session: inout Session,
	) throws {
		guard
			detail,
			let first: Candidate = frames[top].first
		else {
			frames[top].first = frames[top].first ?? value

			return
		}

		var kept: [Candidate] = []

		for existing: Candidate in CollectionOfOne(first) + frames[top].rest {
			try session.store.budget.spend()

			let order: DerivationStore.Ordering
			= history
				? try session.store.compareHistories(
					value.history,
					existing.history,
				)
				: try session.store.compare(
					value.selections,
					existing.selections,
				)

			switch order {
				case .worse:
					return
				case .same:
					if try history || session.store.equal(value, existing) {
						return
					}

					kept.append(existing)
				case .unordered:
					kept.append(existing)
				case .better:
					break
			}
		}

		kept.append(value)
		frames[top].first = kept[0]
		frames[top].rest = Array(kept.dropFirst())
	}

	// MARK: 記号ノード

	private mutating func stepNode(
		_ top: Int,
		_ returned: inout Values,
		_ session: inout Session,
	) throws {
		let target: Int32
		= frames[top].target

		let node: Chart.Node
		= chart.nodes[Int(target)]

		switch frames[top].stage {
			case .awaitingFamily:
				try transform(returned, top, &session)
				frames[top].stage = .next

			default:
				let nonterminal: GrammarModel.Nonterminal
				= session.model.nonterminals[
					Int(chart.calls[Int(node.call)].nonterminal)
				]

				// 明示Triviaは範囲全体が一つの葉になり、内部の導出を見ない。
				if case .explicitTrivia = nonterminal.kind {
					let call: Chart.Call
					= chart.calls[Int(node.call)]

					try addCandidate(
						explicitTrivia(
							nonterminal,
							begin: call.position,
							end: node.end,
							&session,
						),
						to: top,
						&session,
					)
					finishFrame(&returned)

					return
				}

				guard
					let family: Int32 = nextFamily(top, node)
				else {
					finishFrame(&returned)

					return
				}

				frames[top].link.left = family

				let item: Chart.Item
				= chart.items[Int(family)]

				if item.left < 0 {
					try transform(.empty, top, &session)
				}
				else if let known: Values = knownItem(
					family,
					context: frames[top].context,
				) {
					try transform(known, top, &session)
				}
				else {
					frames[top].stage = .awaitingFamily
					frames.append(
						.init(
							isNode: false,
							target: family,
							context: frames[top].context,
						),
					)
				}
		}
	}

	private mutating func nextFamily(
		_ top: Int,
		_ node: Chart.Node,
	) -> Int32? {
		let cursor: Int32
		= frames[top].cursor

		if cursor == -2 {
			frames[top].cursor = node.more

			return node.family
		}

		guard
			cursor >= 0
		else { return nil }

		let chain: Chart.Chain
		= chart.families[Int(cursor)]

		frames[top].cursor = chain.next

		return chain.value
	}

	private func explicitTrivia(
		_ nonterminal: GrammarModel.Nonterminal,
		begin: Int32,
		end: Int32,
		_ session: inout Session,
	) -> Candidate {
		let tree: Int32
		= session.store.tree(
			grammar: nonterminal.grammar,
			label: session.model.triviaLabel,
			begin: begin,
			end: end,
		)

		return detail
			? session.store.leaf(trees: tree, atom: session.model.triviaAtom)
			: .init(trees: tree)
	}

	/// 生成規則の完了を、左辺の種類に従って候補へ反映する。
	private mutating func transform(
		_ source: Values,
		_ top: Int,
		_ session: inout Session,
	) throws {
		let target: Int32
		= frames[top].target

		let node: Chart.Node
		= chart.nodes[Int(target)]

		let family: Int32
		= frames[top].link.left

		let dot: Int32
		= chart.items[Int(family)].dot

		let production: GrammarModel.Production
		= session.model.productions[Int(session.model.owners[Int(dot)])]

		let nonterminal: GrammarModel.Nonterminal
		= session.model.nonterminals[Int(production.lhs)]

		for offset: Int32 in 0..<source.count {
			try session.store.budget.spend()

			let value: Candidate
			= try transform(
				values[Int(source.start + offset)],
				production,
				nonterminal,
				end: node.end,
				&session,
			)

			switch nonterminal.kind {
				case .scoped, .loop:
					try addCompeting(value, to: top, history: false, &session)
				case .loopPrefix:
					try addCompeting(value, to: top, history: true, &session)
				default:
					try addCandidate(value, to: top, &session)
			}
		}
	}

	private func transform(
		_ source: Candidate,
		_ production: GrammarModel.Production,
		_ nonterminal: GrammarModel.Nonterminal,
		end: Int32,
		_ session: inout Session,
	) throws -> Candidate {
		var value: Candidate
		= source

		switch nonterminal.kind {
			case let .scoped(scope, label):
				value.rank += production.rank

				var output: Candidate
				= detail
					? session.store.enclosed(value, scope: scope)
					: .init(trees: value.trees, trivia: value.trivia)

				if label >= 0 {
					output.trees = session.store.branch(
						grammar: nonterminal.grammar,
						label: label,
						children: value.trees,
						cursor: end,
					)
				}

				return output

			case .transparent, .capture:
				value.rank += production.rank

				return value

			case let .relabel(label):
				value.rank += production.rank
				value.trees = session.store.relabeled(value.trees, label: label)

				return value

			case .loopPrefix, .whole:
				return value

			case let .loop(scope):
				guard
					detail
				else { return .init(trees: value.trees, trivia: value.trivia) }

				let ending: Candidate

				if case let .stop(control) = production.action {
					ending = session.store.enclosed(
						.init(),
						scope: control,
						rank: production.rank,
					)
				}
				else {
					ending = .init()
				}

				return session.store.enclosed(
					try session.store.finish(value.history, ending: ending),
					scope: scope,
				)

			case .skip, .explicitTrivia:
				preconditionFailure("候補を作らない記号")
		}
	}

	// MARK: 項目

	private mutating func stepItem(
		_ top: Int,
		_ returned: inout Values,
		_ session: inout Session,
	) throws {
		let target: Int32
		= frames[top].target

		let item: Chart.Item
		= chart.items[Int(target)]

		switch frames[top].stage {
			case .next, .awaitingFamily:
				guard
					let link: (left: Int32, right: Int32)
						= nextLink(top, item)
				else {
					finishFrame(&returned)

					return
				}

				frames[top].link = link

				let left: Chart.Item
				= chart.items[Int(link.left)]

				if left.left < 0 {
					frames[top].left = .empty
					frames[top].stage = .right
				}
				else if let known: Values = knownItem(
					link.left,
					context: frames[top].context,
				) {
					frames[top].left = known
					frames[top].stage = .right
				}
				else {
					frames[top].stage = .awaitingLeft
					frames.append(
						.init(
							isNode: false,
							target: link.left,
							context: frames[top].context,
						),
					)
				}

			case .awaitingLeft:
				frames[top].left = returned
				frames[top].stage = .right

			case .right:
				if frames[top].left.count == 0 {
					frames[top].stage = .next

					return
				}

				try resolveRight(top, item, &session)

			case .awaitingRight:
				frames[top].right = returned
				frames[top].stage = .product

			case .product:
				try product(top, item, &session)
				frames[top].stage = .next
		}
	}

	private mutating func nextLink(
		_ top: Int,
		_ item: Chart.Item,
	) -> (left: Int32, right: Int32)? {
		let cursor: Int32
		= frames[top].cursor

		if cursor == -2 {
			frames[top].cursor = item.more

			return (item.left, item.right)
		}

		guard
			cursor >= 0
		else { return nil }

		let link: Chart.Link
		= chart.links[Int(cursor)]

		frames[top].cursor = link.next

		return (link.left, link.right)
	}

	/// ドットの直前の記号が表す子の候補を求める。
	private mutating func resolveRight(
		_ top: Int,
		_ item: Chart.Item,
		_ session: inout Session,
	) throws {
		let link: (left: Int32, right: Int32)
		= frames[top].link

		let position: Int32
		= chart.items[Int(link.left)].position

		frames[top].stage = .product

		switch session.model.symbols[Int(item.dot) - 1] {
			case let .nonterminal(nonterminal, _):
				if case .skip
					= session.model.nonterminals[Int(nonterminal)].kind
				{
					frames[top].right = try ruleTrivia(
						link.right,
						grammar: session.model.nonterminals[Int(nonterminal)].grammar,
						&session,
					)

					return
				}

				let parent: Int32
				= frames[top].context

				let inner: Int32
				= context(
					of: link.right,
					parentContext: parent,
					&session,
				)

				if isActive(link.right, context: inner) {
					frames[top].cyclic = true
					frames[top].right = .none

					return
				}

				if let known: Values = knownNode(
					link.right,
					context: parent,
					&session,
				) {
					frames[top].right = known

					return
				}

				frames[top].stage = .awaitingRight
				pushNode(link.right, parentContext: parent, &session)

			case let .lexeme(lexeme):
				let site: GrammarModel.Lexeme
				= session.model.lexemes[Int(lexeme)]

				frames[top].right = store(
					leaf(
						trees: session.store.tree(
							grammar: site.grammar,
							label: site.label,
							begin: link.right,
							end: item.position,
						),
						atom: site.atom,
						&session,
					),
				)

			case let .reference(reference):
				let site: GrammarModel.Reference
				= session.model.references[Int(reference)]

				frames[top].right = store(
					leaf(
						trees: session.store.tree(
							grammar: site.grammar,
							label: session.model.noneLabel,
							begin: position,
							end: item.position,
						),
						atom: site.atom,
						&session,
					),
				)

			case let .boundary(boundary):
				let site: GrammarModel.Boundary
				= session.model.boundaries[Int(boundary)]

				if site.probe {
					frames[top].right = .empty

					return
				}

				frames[top].right = store(
					leaf(
						trees: session.matches[Int(link.right)].trees,
						atom: site.atom,
						trivia: session.matches[Int(link.right)].trivia,
						&session,
					),
				)

			case let .point(point):
				let site: GrammarModel.Point
				= session.model.points[Int(point)]

				frames[top].right = store(
					leaf(
						trees: session.store.branch(
							grammar: site.grammar,
							label: session.model.nilLabel,
							children: 0,
							cursor: position,
						),
						atom: site.atom,
						&session,
					),
				)

			case .trivia, .eos:
				frames[top].right = .empty

			case .never, .end:
				preconditionFailure("導出の子にならない記号")
		}
	}

	private func leaf(
		trees: Int32,
		atom: Int32,
		trivia: Int32 = 0,
		_ session: inout Session,
	) -> Candidate {
		detail
			? session.store.leaf(trees: trees, atom: atom, trivia: trivia)
			: .init(trees: trees, trivia: trivia)
	}

	/// skipの記号ノードの読み方を一つに決め、読み飛ばした構文Triviaの列を返す。
	///
	/// 読み方が複数あるときは、先頭から順に各構文Triviaが最も長くなるものを採る。
	/// 探索が終わってから同じ到達の読み方をすべて比べるので、処理順には依存しない。
	private mutating func ruleTrivia(
		_ root: Int32,
		grammar: Int32,
		_ session: inout Session,
	) throws -> Values {
		if triviaSteps.isEmpty {
			triviaSteps = .init(
				repeating: .init(),
				count: chart.nodes.count,
			)
		}

		guard
			!triviaSteps[Int(root)].values.isResolved
		else { return triviaSteps[Int(root)].values }

		var pending: [Int32] = [root]

		while let node: Int32 = pending.last {
			try session.store.budget.spend()

			if triviaSteps[Int(node)].values.isResolved {
				pending.removeLast()
			}
			else {
				try resolveTriviaStep(
					node,
					grammar: grammar,
					&pending,
					&session,
				)
			}
		}

		return triviaSteps[Int(root)].values
	}

	/// 一つのskipの記号ノードの読み方を決める。
	/// 前のskipが未解決なら、それらを `pending` に積んで戻る。
	private mutating func resolveTriviaStep(
		_ node: Int32,
		grammar: Int32,
		_ pending: inout [Int32],
		_ session: inout Session,
	) throws {
		var best: TriviaStep?
		var waiting: Bool = false

		for var candidate: TriviaStep in triviaCandidates(
			of: node,
			model: session.model,
		) {
			try session.store.budget.spend()

			if candidate.parent >= 0 {
				let parent: TriviaStep
				= triviaSteps[Int(candidate.parent)]

				guard
					parent.values.isResolved
				else {
					pending.append(candidate.parent)
					waiting = true

					continue
				}

				candidate.depth = parent.depth + 1
			}

			guard
				!waiting
			else { continue }

			if let current: TriviaStep = best {
				if try isLonger(candidate, than: current, &session) {
					best = candidate
				}
			}
			else {
				best = candidate
			}
		}

		guard
			!waiting,
			var step: TriviaStep = best
		else { return }

		step.values = triviaValues(of: step, grammar: grammar, &session)
		triviaSteps[Int(node)] = step
	}

	/// skipの記号ノードに至る読み方を列挙する。
	/// 構文Triviaを読まない導出は、親のない一件になる。
	private func triviaCandidates(
		of node: Int32,
		model: GrammarModel,
	) -> [TriviaStep] {
		var output: [TriviaStep] = []

		forEachFamily(of: node) { family in
			let item: Chart.Item
			= chart.items[Int(family)]

			// skipの生成規則は、字句Triviaだけか、skip＋構文Trivia＋字句Trivia。
			if item.left >= 0,
				case .trivia = model.symbols[Int(item.dot) - 1]
			{
				forEachLink(of: family) { left, _ in
					appendTriviaCandidates(endingAt: left, to: &output)
				}
			}
			else {
				appendTriviaCandidates(endingAt: family, to: &output)
			}
		}

		return output
	}

	/// 構文Triviaの直後の項目から、読み方を列挙する。
	private func appendTriviaCandidates(
		endingAt id: Int32,
		to output: inout [TriviaStep],
	) {
		let end: Chart.Item
		= chart.items[Int(id)]

		guard
			end.left >= 0
		else {
			output.append(.init())

			return
		}

		forEachLink(of: id) { start, _ in
			let begin: Int32
			= chart.items[Int(start)].position

			forEachLink(of: start) { _, previous in
				output.append(
					.init(
						parent: previous,
						begin: begin,
						end: end.position,
					),
				)
			}
		}
	}

	private func forEachFamily(
		of node: Int32,
		_ body: (Int32) -> Void,
	) {
		body(chart.nodes[Int(node)].family)

		var cursor: Int32
		= chart.nodes[Int(node)].more

		while cursor >= 0 {
			body(chart.families[Int(cursor)].value)
			cursor = chart.families[Int(cursor)].next
		}
	}

	private func forEachLink(
		of id: Int32,
		_ body: (_ left: Int32, _ right: Int32) -> Void,
	) {
		let item: Chart.Item
		= chart.items[Int(id)]

		body(item.left, item.right)

		var cursor: Int32
		= item.more

		while cursor >= 0 {
			let link: Chart.Link
			= chart.links[Int(cursor)]

			body(link.left, link.right)
			cursor = link.next
		}
	}

	/// 先頭から比べて、最初に異なる構文Triviaが長ければ `true`。
	///
	/// 同じ到達の読み方どうしなので、片方がもう片方の先頭部分になることはない。
	private func isLonger(
		_ candidate: TriviaStep,
		than other: TriviaStep,
		_ session: inout Session,
	) throws -> Bool {
		var left: TriviaStep = candidate
		var right: TriviaStep = other

		while left.depth > right.depth {
			try session.store.budget.spend()
			left = triviaSteps[Int(left.parent)]
		}

		while right.depth > left.depth {
			try session.store.budget.spend()
			right = triviaSteps[Int(right.parent)]
		}

		while left.parent != right.parent {
			try session.store.budget.spend()
			left = triviaSteps[Int(left.parent)]
			right = triviaSteps[Int(right.parent)]
		}

		return left.end > right.end
	}

	/// 前のskipの列に、最後の構文Triviaの範囲をつなぐ。
	private mutating func triviaValues(
		of step: TriviaStep,
		grammar: Int32,
		_ session: inout Session,
	) -> Values {
		guard
			step.parent >= 0
		else { return .empty }

		let parent: TriviaStep
		= triviaSteps[Int(step.parent)]

		let span: Int32
		= session.store.triviaList(
			grammar: grammar,
			begin: step.begin,
			end: step.end,
			continuing: parent.depth > 0,
		)

		return store(
			.init(
				trivia: session.store.joinedTrivia(
					values[Int(parent.values.start)].trivia,
					span,
				),
			),
		)
	}

	private mutating func store(
		_ value: Candidate,
	) -> Values {
		values.append(value)

		return .init(start: Int32(values.count - 1), count: 1)
	}

	/// 前半と子の候補を組み合わせる。
	private mutating func product(
		_ top: Int,
		_ item: Chart.Item,
		_ session: inout Session,
	) throws {
		let left: Values
		= frames[top].left

		let right: Values
		= frames[top].right

		let initial: Bool
		= chart.items[Int(frames[top].link.left)].left < 0

		let production: GrammarModel.Production
		= session.model.productions[Int(session.model.owners[Int(item.dot)])]

		for l: Int32 in 0..<left.count {
			for r: Int32 in 0..<right.count {
				try session.store.budget.spend()

				let head: Candidate
				= values[Int(left.start + l)]

				let tail: Candidate
				= values[Int(right.start + r)]

				try addCandidate(
					initial
						? tail
						: join(head, tail, production, &session),
					to: top,
					&session,
				)
			}
		}
	}

	private func join(
		_ head: Candidate,
		_ tail: Candidate,
		_ production: GrammarModel.Production,
		_ session: inout Session,
	) -> Candidate {
		let control: Int32

		switch production.action {
			case let .iterate(value), let .final(value):
				control = value
			default:
				return session.store.joined(head, tail)
		}

		// 反復の本文は一回分の範囲に閉じて、前半の回の列へ加える。
		guard
			detail
		else {
			let joined: Candidate
			= session.store.joined(head, tail)

			return .init(trees: joined.trees, trivia: joined.trivia)
		}

		return .init(
			history: session.store.iteration(
				previous: head.history,
				control: control,
				rank: production.rank,
				body: tail,
			),
		)
	}

}
