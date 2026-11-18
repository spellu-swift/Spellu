import Basis
import SpelluCore



/// 式の先頭だけを読む。連結をChoiceへ一括分配しない。
final class PackedSelection {
	enum Kind: Int, Hashable {
		case empty, cons, fragment, leaf, scope, chain, link, iteration
		case sourceTree, branchTree, token, outcome
	}
	enum Op: Hashable {
		case get(Int), concat, add, count, first, initial, last
		case initialTail, lastTail, linkTail
		case relabel(Int), treeLabel(Int), sourceParts(Int)
		case loopNodes, loopPathAtoms, following, loopLinks, endingLinks
		case loopSelection, tokens, atomTokens, childTokens, linkTokens
		case equal, all, freeze, tokenRank, tokenValue, tokenTail
		case restrict(Int), rangeBegin, rangeEnd
	}
	enum Expr: Hashable {
		case integer(Int)
		case value(Kind, [Int])
		case choice(Int, [Int])
		case call(Op, [Int])
		case use(Int)
	}
	struct Use: Hashable {
		let plan: Int
		let renames: [Int: Int]
	}
	private enum Demand: Error {
		case need(Int)
		case split(Int, [Int], Int)
	}
	let evaluation: Evaluation
	let forest: PackedPlan
	let diagram: DecisionDiagram
	var session: Session { evaluation.session }
	private var expressions: [Expr] = []
	private var index: [Expr: Int] = [:]
	private var normal: [Int: Int] = [:]
	private var redirects: [Int: Int] = [:]
	private var uses: [Use] = []
	private var useIndex: [Use: Int] = [:]
	private var expanded: [Int: Int] = [:]
	private var triviaRoots: [Int: Int] = [:]
	/// 展開時に複製した選択変数を持つ、枝ごとの子の使用式。
	private var triviaUses: [Int: [[Int]]] = [:]
	/// 保存するのは読出し値ごとの条件。導出全体の組を保存しない。
	private var observationMemo: [Int: [Int: Int]] = [:]
	private var supports: [Int: Set<Int>] = [:]
	private var variables: [Int: Int] = [:]
	private var scopes: [ScopeKey: Int] = [:]
	private var atoms: [PathAtom: Int] = [:]
	private var labels: [Label] = []
	private var labelIDs: [Label: Int] = [:]
	private var leaves: [Int: Int] = [:]
	private var assignment: [Int: Int] = [:]
	private(set) var root: Int = 0
	private var singleRoot: Int = 0
	private var empty: Int = 0
	private var zero: Int = 0
	private var one: Int = 0
	private var leaf: Int = 0

	init(evaluation: Evaluation, roots: [Int]) throws {
		self.evaluation = evaluation
		forest = try .init(session: evaluation.session, results: evaluation.results)
		diagram = .init(step: evaluation.session.budget.spend)
		empty = try put(.value(.empty, []))
		zero = try integer(0)
		one = try integer(1)
		leaf = try value(.leaf, [])
		var plans: [Int] = []
		for result: Int in roots {
			let plan: Int = try forest.build(result)
			if plan >= 0 { plans.append(plan) }
		}
		guard !plans.isEmpty else { throw ParseFailure.noMatch }
		singleRoot = plans[0]
		let rootVariable: Int? = plans.count > 1
			? try diagram.variable(width: plans.count) : nil
		// 逆後行順なので、共有された子を含む全辺で親が先になる。
		for id: Int in forest.plans.indices.reversed() {
			let plan: PackedPlan.Plan = forest.plans[id]
			if plan.families.count > 1 {
				variables[id] = try diagram.variable(width: plan.families.count)
			}
		}

		var outcomes: [Int] = []
		for plan: Int in plans {
			let result: Int = forest.plans[plan].result
			let resultExpression: Int = try integer(result)
			let body: Int = try use(plan, [:])
			if forest.plans[plan].hasTrivia {
				triviaRoots[result] = body
			}
			outcomes.append(try value(.outcome, [resultExpression, body]))
		}
		root = try rootVariable.map { try put(.choice($0, outcomes)) }
			?? outcomes[0]
	}


	private func put(_ expression: Expr) throws -> Int {
		if case let .choice(_, branches) = expression,
			branches.allSatisfy({ $0 == branches[0] }) { return branches[0] }
		if let known: Int = index[expression] { return known }
		try session.budget.spend()
		let id: Int = expressions.count
		expressions.append(expression)
		index[expression] = id
		return id
	}
	private func integer(_ number: Int) throws -> Int {
		try put(.integer(number))
	}
	private func value(_ kind: Kind, _ fields: [Int]) throws -> Int {
		try put(.value(kind, fields))
	}
	private func call(_ op: Op, _ args: [Int]) throws -> Int {
		try put(.call(op, args))
	}
	private func get(_ expression: Int, _ field: Int) throws -> Int {
		try call(.get(field), [expression])
	}
	private func cons(_ head: Int, _ tail: Int) throws -> Int {
		try value(.cons, [head, tail])
	}
	private func list(_ items: [Int]) throws -> Int {
		var result: Int = empty
		for item: Int in items.reversed() { result = try cons(item, result) }
		return result
	}
	private func scopeID(_ scope: ScopeKey) -> Int {
		if let id: Int = scopes[scope] { return id }
		let id: Int = scopes.count
		scopes[scope] = id
		return id
	}
	private func atomID(_ atom: PathAtom) -> Int {
		if let id: Int = atoms[atom] { return id }
		let id: Int = atoms.count
		atoms[atom] = id
		return id
	}

	private func labelID(_ label: Label) -> Int {
		if let id: Int = labelIDs[label] { return id }
		let id: Int = labels.count
		labels.append(label)
		labelIDs[label] = id
		return id
	}

	private func use(_ plan: Int, _ renames: [Int: Int]) throws -> Int {
		let key: Use = .init(plan: plan, renames: renames.filter {
			forest.plans[plan].support.contains($0.key)
		})
		if let id: Int = useIndex[key] { return try put(.use(id)) }
		try session.budget.spend()
		let id: Int = uses.count
		uses.append(key)
		useIndex[key] = id
		return try put(.use(id))
	}

	private func expand(_ id: Int) throws -> Int {
		if let found: Int = expanded[id] { return found }
		let use: Use = uses[id]
		let plan: PackedPlan.Plan = forest.plans[use.plan]
		var branches: [Int] = []
		var triviaChildren: [[Int]] = []
		for family in plan.families {
			var occupied: Set<Int> = []
			var children: [Int] = []
			var withTrivia: [Int] = []
			for child: Int in family.children {
				var renames: [Int: Int] = use.renames
				let support: Set<Int> = forest.plans[child].support
				// 同時に使う兄弟だけを分離する。排他的な枝には複製しない。
				for symbol: Int in support.intersection(occupied).sorted() {
					renames[symbol] = try diagram.replica(of: variables[symbol]!)
				}
				for symbol: Int in support {
					try session.budget.spend()
					occupied.insert(symbol)
				}
				let expression: Int = try self.use(child, renames)
				children.append(expression)
				if forest.plans[child].hasTrivia {
					withTrivia.append(expression)
				}
			}
			branches.append(try apply(family.action, children, plan.result))
			if plan.hasTrivia {
				triviaChildren.append(withTrivia)
			}
		}
		if plan.hasTrivia {
			triviaUses[id] = triviaChildren
		}
		let result: Int
		if branches.count == 1 { result = branches[0] }
		else {
			result = try put(.choice(
				use.renames[use.plan] ?? variables[use.plan]!, branches
			))
		}
		expanded[id] = result
		return result
	}

	private func fragment(_ fields: [Int]? = nil) throws -> Int {
		try value(.fragment, fields ?? [empty, empty, empty, zero, empty])
	}
	private func scoped(_ scope: ScopeKey, _ body: Int, _ rank: Int? = nil) throws -> Int {
		try fragment([
			get(body, 0), list([integer(atomID(.scope(scope)))]),
			list([value(.scope, [integer(scopeID(scope)),
				rank ?? get(body, 3), get(body, 1), get(body, 2)])]),
			zero, empty,
		])
	}
	private func nativeTree(_ id: Int) throws -> Int {
		if let found: Int = leaves[id] { return found }
		let tree: DerivationStore.Tree = session.store.trees[id]
					let result: Int = try value(.sourceTree, [integer(tree.grammar.index),
			integer(labelID(tree.label)), integer(tree.begin), integer(tree.end),
			call(.sourceParts(id), [])])
		leaves[id] = result
		return result
	}
	private func apply(_ action: DerivationAction, _ children: [Int], _ result: Int) throws -> Int {
		var body: Int = try fragment()
		for (index, child) in children.enumerated() {
			if index == 0 { body = child; continue }
			if case let .iteration(expression, state, rank, _) = action, index == 1 {
				let plan: GrammarModel.LoopPlan = evaluation.loop(expression)
				let scope: ScopeKey = .loop(plan.control,
					max(plan.minimum - state.count, 0), plan.maximum.map { $0 - state.count })
				let item: Int = try value(.iteration, [integer(scopeID(scope)), integer(rank),
					scoped(.fixed(plan.bodyScope), child), integer(atomID(.scope(scope)))])
				body = try fragment([empty, empty, empty, zero,
					call(.concat, [get(body, 4), list([item])])])
				continue
			}
			var fields: [Int] = []
			for field: Int in 0..<5 {
				fields.append(try call(field == 3 ? .add : .concat,
					[get(body, field), get(child, field)]))
			}
			body = try fragment(fields)
		}
		switch action {
			case .empty: return try fragment()
			case .join: return body
			case let .ranked(rank):
				return try fragment([get(body, 0), get(body, 1), get(body, 2),
					call(.add, [get(body, 3), integer(rank)]), get(body, 4)])
			case let .optional(outer, inner, present):
				return try scoped(.fixed(outer), present ? scoped(.fixed(inner), body) : body,
					present ? one : zero)
			case let .relabel(label):
				return try fragment([call(.relabel(labelID(label)), [get(body, 0)]),
					get(body, 1), get(body, 2), get(body, 3), get(body, 4)])
			case let .scope(scope, owner, label):
				let wrapped: Int = try scoped(.fixed(scope), body)
				guard let label else { return wrapped }
				let nodes: Int = try get(body, 0)
				let cursor: Int = try integer(forest.results[result].output.position)
				let tree: Int = try value(.sourceTree, [integer(owner.index), integer(labelID(label)),
					call(.rangeBegin, [nodes, cursor]), call(.rangeEnd, [nodes, cursor]), nodes])
				return try fragment([list([tree]), get(wrapped, 1), get(wrapped, 2), zero, empty])
			case let .leaf(tree, atom):
				return try fragment([list([nativeTree(tree)]), list([integer(atomID(atom))]),
					list([leaf]), zero, empty])
			case let .committed(trees, atom):
				let nodes: [Int] = try session.store.treeLists.values(trees)
				return try fragment([list(nodes.map { try nativeTree($0) }),
					list([integer(atomID(atom))]), list([leaf]), zero, empty])
			case .iteration(_, _, _, false): return body
			case .iteration(_, _, _, true), .stop, .limit:
				let history: Int = try get(body, 4)
				let ending: Int
				if case let .stop(expression, state, rank) = action {
					let plan: GrammarModel.LoopPlan = evaluation.loop(expression)
					ending = try scoped(.loop(plan.control, max(plan.minimum - state.count, 0),
						plan.maximum.map { $0 - state.count }), fragment(), integer(rank))
				} else { ending = try fragment() }
				let links: Int = try call(.loopLinks, [history, get(ending, 2), get(ending, 1)])
				return try fragment([call(.loopNodes, [history, get(ending, 0)]),
					call(.loopPathAtoms, [history, get(ending, 1)]),
					call(.loopSelection, [links, get(ending, 2)]), zero, empty])
		}
	}

	private func support(_ root: Int) throws -> Set<Int> {
		var pending: [Int] = [root]
		while let id: Int = pending.last {
			if supports[id] != nil { pending.removeLast(); continue }
			try session.budget.spend()
			var symbols: Set<Int> = []
			let children: [Int]
			switch expressions[id] {
				case .integer, .call(.freeze, _): children = []
				case let .use(index):
					// 複製も元の変数で保守的に数え、使用箇所は開かない。
					for symbol: Int in forest.plans[uses[index].plan].support {
						symbols.insert(variables[symbol]!)
					}
					children = []
				case let .choice(variable, branches):
					symbols.insert(diagram.origins[variable])
					children = branches
				case let .value(_, fields), let .call(_, fields): children = fields
			}
			if let missing: Int = children.first(where: { supports[$0] == nil }) {
				pending.append(missing)
				continue
			}
			for child: Int in children { symbols.formUnion(supports[child]!) }
			supports[id] = symbols
			pending.removeLast()
		}
		return supports[root]!
	}

	private func head(_ root: Int) throws -> Int {
		var pending: [Int] = [root]
		while let id: Int = pending.last {
			if normal[id] != nil { pending.removeLast(); continue }
			try session.budget.spend()
			if let target: Int = redirects[id] {
				if let found: Int = normal[target] { normal[id] = found }
				else { pending.append(target) }
				continue
			}
			let target: Int
			switch expressions[id] {
				case let .choice(variable, branches):
					if let missing: Int = branches.first(where: { normal[$0] == nil }) {
						pending.append(missing)
						continue
					}
					let values: [Int] = branches.map { normal[$0]! }
					if values.allSatisfy({ $0 == values[0] }) {
						normal[id] = values[0]
						continue
					}
					if case let .value(kind, fields) = expressions[values[0]],
						values.allSatisfy({
							if case let .value(k, f) = expressions[$0] {
								return k == kind && f.count == fields.count
							}
							return false
						}) {
						var shared: [Int] = []
						for field: Int in fields.indices {
							let alternatives: [Int] = values.map {
								guard case let .value(_, f) = expressions[$0]
								else { preconditionFailure() }
								return f[field]
							}
							shared.append(try put(.choice(variable, alternatives)))
						}
						target = try value(kind, shared)
					}
					else {
						normal[id] = try put(.choice(variable, values))
						continue
					}
				case .integer, .value:
					normal[id] = id
					continue
				case let .use(use): target = try expand(use)
				case let .call(op, args):
					do { target = try reduce(op, args) }
					catch let Demand.need(child) { pending.append(child); continue }
					catch let Demand.split(variable, branches, argument) {
						var values: [Int] = []
						for branch: Int in branches {
							var modified: [Int] = args
							modified[argument] = branch
							values.append(try call(op, modified))
						}
						target = try put(.choice(variable, values))
					}
			}
			redirects[id] = target
			if let found: Int = normal[target] { normal[id] = found }
			else { pending.append(target) }
		}
		return normal[root]!
	}

	private func reduce(_ op: Op, _ args: [Int]) throws -> Int {
		func read(_ i: Int) throws -> Expr {
			guard let id: Int = normal[args[i]] else { throw Demand.need(args[i]) }
			if case let .choice(variable, branches) = expressions[id] {
				throw Demand.split(variable, branches, i)
			}
			return expressions[id]
		}
		func fields(_ i: Int) throws -> (Kind, [Int]) {
			guard case let .value(kind, fields) = try read(i)
			else { preconditionFailure("構造値が必要") }
			return (kind, fields)
		}
		func number(_ i: Int) throws -> Int {
			guard case let .integer(value) = try read(i)
			else { preconditionFailure("整数値が必要") }
			return value
		}
		func token(_ number: Int, rank: Bool = false) throws -> Int {
			try value(.token, [rank ? one : zero, number])
		}
		switch op {
			// 元の条件下で等しい式へ変換する。親の条件は呼出し側に残す。
			case let .restrict(condition):
				if condition == 1 { return args[0] }
				let restricted: Int = normal[args[0]] ?? args[0]
				let projected: Int = try diagram.project(
					condition, keepingOrigins: support(restricted)
				)
				if projected != condition {
					return try call(.restrict(projected), [restricted])
				}
				switch expressions[restricted] {
					case let .choice(variable, branches):
						var filtered: [Int?] = []
						for (index, branch) in branches.enumerated() {
							let joint: Int = try diagram.and(
								condition, diagram.equals(variable, index)
							)
							filtered.append(joint == 0 ? nil : try call(.restrict(joint), [branch]))
						}
						let fallback: Int = filtered.compactMap { $0 }.first!
						return try put(.choice(variable, filtered.map { $0 ?? fallback }))
					case let .value(kind, children):
						return try value(kind, children.map { try call(op, [$0]) })
					case let .call(.restrict(previous), children):
						return try call(.restrict(diagram.and(condition, previous)), children)
					case let .call(operation, children):
						return try call(operation, children.map { try call(op, [$0]) })
					case let .use(id): return try call(op, [expand(id)])
					case .integer: return args[0]
				}
			case .freeze:
				guard let id: Int = normal[args[0]] else {
					throw Demand.need(args[0])
				}
				switch expressions[id] {
					case let .choice(variable, branches):
						return try call(.freeze, [branches[assignment[variable] ?? 0]])
					case let .value(kind, children):
						return try value(kind, children.map { try call(.freeze, [$0]) })
					case .integer: return id
					default: preconditionFailure()
				}
			case let .get(index): return try fields(0).1[index]
			case .concat:
				let (kind, items) = try fields(0)
				if kind == .empty { return args[1] }
				return try cons(items[0], call(.concat, [items[1], args[1]]))
			case .add: return try integer(number(0) + number(1))
			case .count:
				let (kind, items) = try fields(0)
				if kind == .empty { return zero }
				return try call(.add, [one, call(.count, [items[1]])])
			case .first:
				let (kind, items) = try fields(0)
				return kind == .empty ? leaf : items[0]
			case .initial, .last:
				let (_, items) = try fields(0)
				let tail: Int = items[1]
				guard let known: Int = normal[tail] else { throw Demand.need(tail) }
				if case .choice = expressions[known] {
					// 尾の分岐を通常の演算へ引き渡して相関を保つ。
					return try call(op == .last ? .lastTail : .initialTail,
						[items[0], tail])
				}
				if case .value(.empty, _) = expressions[known] {
					return op == .last ? items[0] : empty
				}
				if op == .last { return try call(.last, [tail]) }
				return try cons(items[0], call(.initial, [tail]))
			case .lastTail, .initialTail:
				let (kind, _) = try fields(1)
				if kind == .empty { return op == .lastTail ? args[0] : empty }
				if op == .lastTail { return try call(.last, [args[1]]) }
				return try cons(args[0], call(.initial, [args[1]]))
			case let .sourceParts(id):
				let tree: DerivationStore.Tree = session.store.trees[id]
				return try list(session.store.treeLists.values(tree.children).map { try nativeTree($0) })
			case .rangeBegin, .rangeEnd:
				let (kind, items) = try fields(0)
				if kind == .empty { return args[1] }
				if op == .rangeBegin { return try get(items[0], 2) }
				return try call(.rangeEnd, [items[1], get(items[0], 3)])

			case let .relabel(label):
				let (kind, items) = try fields(0)
				if kind == .empty { return empty }
				return try cons(call(.treeLabel(label), [items[0]]),
					call(op, [items[1]]))
			case let .treeLabel(label):
				var (kind, items) = try fields(0)
				items[1] = try integer(label)
				return try value(kind, items)
			case .loopNodes, .loopPathAtoms, .following:
				let (kind, items) = try fields(0)
				if kind == .empty { return args[1] }
				if op != .loopNodes { return try list([get(items[0], 3)]) }
				return try call(.concat, [get(get(items[0], 2), 0),
					call(.loopNodes, [items[1], args[1]])])
			case .loopLinks:
				let (kind, items) = try fields(0)
				if kind == .empty { return try call(.endingLinks, [args[1]]) }
				let iteration: Int = items[0]
				let body: Int = try get(iteration, 2)
				let link: Int = try value(.link, [get(iteration, 0),
					get(iteration, 1), call(.concat, [get(body, 1),
						call(.following, [items[1], args[2]])]), get(body, 2)])
				return try cons(link, call(.loopLinks, [items[1], args[1], args[2]]))
			case .endingLinks:
				let (kind, items) = try fields(0)
				if kind == .empty { return empty }
				return try cons(value(.link, (0..<4).map { try get(items[0], $0) }),
					call(.endingLinks, [items[1]]))
			case .loopSelection:
				let (kind, _) = try fields(0)
				if kind == .empty { return args[1] }
				return try list([value(.chain, [args[0]])])
			case .tokens:
				let (kind, items) = try fields(0)
				switch kind {
					case .leaf: return try list([token(zero)])
					case .scope:
						let prefix: Int = try list([token(one), token(items[0]),
							token(items[1], rank: true), token(call(.count, [items[2]]))])
						return try call(.concat, [prefix, call(.concat, [
							call(.atomTokens, [items[2]]), cons(
								token(call(.count, [items[3]])),
								call(.childTokens, [items[3]]))])])
					case .chain:
						return try cons(token(integer(2)), call(.linkTokens, [items[0]]))
					default: preconditionFailure()
				}
			case .atomTokens, .childTokens:
				let (kind, items) = try fields(0)
				if kind == .empty { return empty }
				if op == .atomTokens {
					return try cons(token(items[0]), call(op, [items[1]]))
				}
				return try call(.concat, [call(.tokens, [items[0]]),
					call(op, [items[1]])])
			case .linkTokens:
				let (kind, items) = try fields(0)
				if kind == .empty { return try list([token(zero)]) }
				let link: Int = items[0]
				let atoms: Int = try get(link, 2)
				let children: Int = try get(link, 3)
				let prefix: Int = try list([token(one), token(get(link, 0)),
					token(get(link, 1), rank: true), token(call(.count, [atoms]))])
				return try call(.concat, [prefix, call(.concat, [
					call(.atomTokens, [atoms]), call(.linkTail, [items[1], children])])])
			case .linkTail:
				let (kind, _) = try fields(0)
				let prefix: Int = try list([token(kind == .empty ? zero : one),
					token(call(.count, [args[1]]))])
				return try call(.concat, [prefix, call(.concat, [
					call(.childTokens, [args[1]]),
					kind == .empty ? empty : call(.linkTokens, [args[0]])])])
			case .tokenRank, .tokenValue, .tokenTail:
				let (kind, items) = try fields(0)
				if kind == .empty {
					return op == .tokenTail ? empty : try integer(-1)
				}
				if op == .tokenTail { return items[1] }
				return try get(items[0], op == .tokenRank ? 0 : 1)
			case .equal:
				if args[0] == args[1] { return one }
				let left: Expr = try read(0), right: Expr = try read(1)
				switch (left, right) {
					case let (.integer(a), .integer(b)): return a == b ? one : zero
					case let (.value(lk, l), .value(rk, r)):
						guard lk == rk, l.count == r.count else { return zero }
						var result: Int = one
						for (a, b) in zip(l, r).reversed() {
							result = try call(.all, [call(.equal, [a, b]), result])
						}
						return result
					default: return zero
				}
			case .all: return try number(0) == 0 ? zero : args[1]
		}
	}

	/// 条件を合併した先頭状態。完成候補や履歴の配列は持たない。
	private func observations(_ expression: Int, under condition: Int) throws -> [Int: Int] {
		guard condition != 0 else { return [:] }
		let root: Int = try head(expression)
		var pending: [Int] = [root]
		while let id: Int = pending.last {
			if observationMemo[id] != nil { pending.removeLast(); continue }
			try session.budget.spend()
			guard case let .choice(variable, branches) = expressions[id] else {
				observationMemo[id] = [id: 1]
				continue
			}
			let children: [Int] = try branches.map { try head($0) }
			if let missing: Int = children.first(where: { observationMemo[$0] == nil }) {
				pending.append(missing)
				continue
			}
			var output: [Int: Int] = [:]
			for (value, child) in children.enumerated() {
				let branch: Int = try diagram.equals(variable, value)
				for (outcome, guardID) in observationMemo[child]! {
					let joint: Int = try diagram.and(branch, guardID)
					output[outcome] = try diagram.or(output[outcome] ?? 0, joint)
				}
			}
			observationMemo[id] = output
			pending.removeLast()
		}
		var output: [Int: Int] = [:]
		for (outcome, guardID) in observationMemo[root]! {
			let joint: Int = try diagram.and(condition, guardID)
			if joint != 0 { output[outcome] = joint }
		}
		return output
	}

	func select() throws -> Session.Match {
		if diagram.widths.isEmpty {
			return try SingleDerivation(evaluation).evaluate(forest, root: singleRoot)
		}
		let body: Int = try get(root, 1)
		let selection: Int = try call(.first, [get(body, 2)])
		let tokens: Int = try call(.tokens, [selection])
		var cursor: Int = tokens
		var domain: Int = 1
		var ambiguous: Bool = false
		func maximize(_ expression: Int, _ condition: Int) throws -> (Int, Int) {
			var best: Int = .min
			var selected: Int = 0
			for (outcome, guardID) in try observations(expression, under: condition) {
				guard case let .integer(number) = expressions[outcome]
				else { preconditionFailure() }
				if selected == 0 || number > best {
					best = number
					selected = guardID
				}
			}
			return (best, selected)
		}
		while true {
			let previousDomain: Int = domain
			let (rank, rankedDomain) = try maximize(call(.tokenRank, [cursor]), domain)
			if domain != rankedDomain { ambiguous = true }
			domain = rankedDomain
			if rank == -1 { break }
			let (_, selectedDomain) = try maximize(call(.tokenValue, [cursor]), domain)
			if rank == 0 && domain != selectedDomain { ambiguous = true }
			domain = selectedDomain
			cursor = try call(.tokenTail, [cursor])
			if domain != previousDomain { cursor = try call(.restrict(domain), [cursor]) }
		}

		assignment = try diagram.witness(domain)
		let fixed: Int = try call(.freeze, [root])
		// 最初に異なるトークンが順位なら劣位、構造なら比較不能。
		// 最大化で得たこの分類を再利用し、同じ履歴を二度走査しない。
		let equalCondition: Int = domain

		if !ambiguous {
			let restricted: Int = try call(.restrict(equalCondition), [root])
			let equality: Int = try call(.equal, [restricted, fixed])
			for (equal, _) in try observations(equality, under: equalCondition) {
				if case .integer(0) = expressions[equal] { ambiguous = true; break }
			}
		}
		if ambiguous {
			let selected: Int = try head(call(.freeze, [selection]))
			var priority: Int = 0
			if case .value(.scope, _) = expressions[selected] {
				priority = try concreteNumber(get(selected, 1))
			}
			throw SpelluError.ambiguousPath(precedence: priority)
		}
		let result: Int = try concreteNumber(get(fixed, 0))
		let trees: Int = try materialize(get(get(fixed, 1), 0))
		let trivia: Int = try triviaRoots[result].map { root in
			try forest.collectTrivia(from: root, select: selectedTriviaBranch)
		} ?? 0
		return .init(
			output: forest.results[result].output,
			trees: trees,
			trivia: trivia
		)
	}

	private func selectedTriviaBranch(
		_ expression: Int,
	) throws -> PackedPlan.TriviaBranch {
		guard case let .use(id) = expressions[expression]
		else { preconditionFailure() }

		let use: Use = uses[id]
		let plan: PackedPlan.Plan = forest.plans[use.plan]
		// 本文と同じ使用式を展開し、同じ割り当てで枝を選ぶ。
		_ = try expand(id)
		let variable: Int? = use.renames[use.plan] ?? variables[use.plan]
		let branch: Int = variable.flatMap { assignment[$0] } ?? 0
		return .init(
			contribution: plan.families[branch].trivia,
			children: triviaUses[id]![branch]
		)
	}

	private func concreteNumber(_ expression: Int) throws -> Int {
		guard case let .integer(number) = expressions[try head(expression)]
		else { preconditionFailure() }
		return number
	}
	private func concreteList(_ expression: Int) throws -> [Int] {
		var cursor: Int = expression
		var result: [Int] = []
		while true {
			guard case let .value(kind, fields) = expressions[try head(cursor)]
			else { preconditionFailure() }
			if kind == .empty { return result }
			result.append(fields[0])
			cursor = fields[1]
		}
	}
	private func materialize(_ expression: Int) throws -> Int {
		struct Frame {
			let fields: [Int]
			let children: [Int]
			var built: [Int] = []
		}
		func frame(_ id: Int) throws -> Frame {
			guard case let .value(.sourceTree, fields) = expressions[try head(id)]
			else { preconditionFailure() }
			return try .init(fields: fields, children: concreteList(fields[4]))
		}
		var output: Int = 0
		for root: Int in try concreteList(expression) {
			var stack: [Frame] = [try frame(root)]
			while let current: Frame = stack.last {
				try session.budget.spend()
				if current.built.count < current.children.count {
					stack.append(try frame(current.children[current.built.count]))
					continue
				}
				var children: Int = 0
				for child: Int in current.built {
					children = try session.store.treeLists.joined(children, session.store.treeLists.single(child))
				}
				let f: [Int] = current.fields
				let tree: Int = try session.store.tree(.init(
					grammar: .init(index: concreteNumber(f[0])), label: labels[concreteNumber(f[1])],
					begin: concreteNumber(f[2]), end: concreteNumber(f[3]), children: children))
				stack.removeLast()
				if stack.isEmpty { output = try session.store.treeLists.joined(output, session.store.treeLists.single(tree)) }
				else { stack[stack.count - 1].built.append(tree) }
			}
		}
		return output
	}
}
