import SpelluCore
@testable import SpelluInterpreter


// API観点：Store.compare(_:_:) の四値の比較と、Store.selection(_:) の番号。
// - 同じ列は同値、長さや比較範囲が違えば比較不能。
// - Atomか順位が違えば順位で決め、同順位なら比較不能。
// - 子の選択履歴は、兄弟の残りより先に比べる（最初の差で決まる）。
@Suite struct InterpreterCandidateTests {

	@Test func 同じ列は同値になる() throws {
		var store: Store = .init()
		let listSelection: SelectionID = selection(&store, .rule(rule(0)), rank: 1)
		let list: ListID<SelectionID> = store.selectionLists.single(listSelection)
		#expect(store.compare(list, list) == .same)
		#expect(store.compare(.empty, .empty) == .same)
	}

	@Test func 長さか比較範囲が違えば比較不能になる() throws {
		var store: Store = .init()
		let a: SelectionID = selection(&store, .rule(rule(0)), rank: 1)
		let b: SelectionID = selection(&store, .rule(rule(1)), rank: 1)
		let one: ListID<SelectionID> = store.selectionLists.single(a)
		let two: ListID<SelectionID> = store.selectionLists.appending(a, to: one)
		#expect(store.compare(one, two) == .unordered)
		let other: ListID<SelectionID> = store.selectionLists.single(b)
		#expect(store.compare(one, other) == .unordered)
	}

	@Test func 順位が違えば大きいほうが優る() throws {
		var store: Store = .init()
		let highSelection: SelectionID = selection(&store, .rule(rule(0)), rank: 2)
		let high: ListID<SelectionID> = store.selectionLists.single(highSelection)
		let lowSelection: SelectionID = selection(&store, .rule(rule(0)), rank: 1)
		let low: ListID<SelectionID> = store.selectionLists.single(lowSelection)
		#expect(store.compare(high, low) == .better)
		#expect(store.compare(low, high) == .worse)
	}

	@Test func 同順位でAtomが違えば比較不能になる() throws {
		var store: Store = .init()
		let leftSelection: SelectionID = selection(&store, .rule(rule(0)), atom: .scope(.rule(rule(1))))
		let left: ListID<SelectionID> = store.selectionLists.single(leftSelection)
		let rightSelection: SelectionID = selection(&store, .rule(rule(0)), atom: .scope(.rule(rule(2))))
		let right: ListID<SelectionID> = store.selectionLists.single(rightSelection)
		#expect(store.compare(left, right) == .unordered)
	}

	@Test func 子の選択履歴を兄弟の残りより先に比べる() throws {
		var store: Store = .init()
		let better: SelectionID = selection(&store, .rule(rule(1)), rank: 1)
		let worse: SelectionID = selection(&store, .rule(rule(1)), rank: 0)

		// 先頭の範囲の子は左が優り、2番目の範囲は右が優る。最初の差で左が優る。
		let leftHead: SelectionID = selection(&store, .rule(rule(0)), children: [better])
		let leftTail: SelectionID = selection(&store, .rule(rule(2)), rank: 0)
		let rightHead: SelectionID = selection(&store, .rule(rule(0)), children: [worse])
		let rightTail: SelectionID = selection(&store, .rule(rule(2)), rank: 5)
		let left: ListID<SelectionID> = list(&store, [leftHead, leftTail])
		let right: ListID<SelectionID> = list(&store, [rightHead, rightTail])
		#expect(store.compare(left, right) == .better)
		#expect(store.compare(right, left) == .worse)
	}

	@Test func 同じ内容の選択履歴には同じ番号を振る() throws {
		var store: Store = .init()
		let a: SelectionID = selection(&store, .rule(rule(0)), rank: 3)
		let b: SelectionID = selection(&store, .rule(rule(0)), rank: 3)
		#expect(a == b)
		#expect(store[a].rank == 3)
		#expect(store.selectionLists.count(store.leafSelections) == 1)
		#expect(
			store[store.selectionLists.first(store.leafSelections)!].scope == .leaf
		)
	}

}


private func rule(
	_ value: Int,
) -> RuleID {
	.init(rawValue: value)
}


private func selection(
	_ store: inout Store,
	_ scope: Scope,
	rank: Int = 0,
	atom: Atom? = nil,
	children: [SelectionID] = [],
) -> SelectionID {
	let atoms: ListID<Atom>
	= atom.map { store.atomLists.single($0) } ?? .empty

	let childList: ListID<SelectionID>
	= list(&store, children)

	return store.selection(
		.init(scope: scope, atoms: atoms, rank: rank, children: childList),
	)
}


private func list(
	_ store: inout Store,
	_ values: [SelectionID],
) -> ListID<SelectionID> {
	var result: ListID<SelectionID> = .empty

	for value: SelectionID in values {
		result = store.selectionLists.appending(value, to: result)
	}

	return result
}
