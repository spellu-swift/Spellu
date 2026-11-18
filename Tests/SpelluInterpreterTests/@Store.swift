import SpelluCore
@testable import SpelluInterpreter


// API観点：
// - ListStore：single・appending・concat・count・first・last・elements、
//   空の列、内容が同じ列の番号、長い列。
// - Store：leaf・branch・subscript、枝の範囲、同じ木の番号。
@Suite struct InterpreterStoreTests {

	@Test func 空の列は要素を持たない() throws {
		let lists: ListStore<Int> = .init()
		#expect(lists.count(.empty) == 0)
		#expect(lists.first(.empty) == nil)
		#expect(lists.last(.empty) == nil)
		#expect(lists.elements(.empty).isEmpty)
	}

	@Test func 列を伸ばしてつないでも順序を保つ() throws {
		var lists: ListStore<Int> = .init()
		let a: ListID<Int> = lists.single(1)
		let ab: ListID<Int> = lists.appending(2, to: a)
		let c: ListID<Int> = lists.single(3)
		let abc: ListID<Int> = lists.concat(ab, c)
		#expect(lists.elements(abc) == [1, 2, 3])
		#expect(lists.count(abc) == 3)
		#expect(lists.first(abc) == 1)
		#expect(lists.last(abc) == 3)
		#expect(lists.concat(.empty, abc) == abc)
		#expect(lists.concat(abc, .empty) == abc)
		#expect(lists.elements(ab) == [1, 2])
	}

	@Test func 内容が同じ列は作り方によらず同じ番号になる() throws {
		var lists: ListStore<Int> = .init()
		let left: ListID<Int> = lists.concat(
			lists.appending(2, to: lists.single(1)),
			lists.single(3),
		)
		let right: ListID<Int> = lists.concat(
			lists.single(1),
			lists.appending(3, to: lists.single(2)),
		)
		#expect(left == right)
		#expect(lists.single(1) != lists.single(2))
	}

	@Test func 長い列でもSwiftの呼び出しを深くしない() throws {
		var lists: ListStore<Int> = .init()
		var list: ListID<Int> = .empty
		for value: Int in 0..<100_000 {
			list = lists.appending(value, to: list)
		}
		#expect(lists.count(list) == 100_000)
		#expect(lists.first(list) == 0)
		#expect(lists.last(list) == 99_999)
		#expect(lists.elements(list) == Array(0..<100_000))
	}

	@Test func 枝の範囲は最初の子から最後の子まで() throws {
		var store: Store = .init()
		let grammar: GrammarID = .init(rawValue: 0)
		let a: TreeID = store.leaf(grammar: grammar, label: "A", begin: 1, end: 2)
		let b: TreeID = store.leaf(grammar: grammar, label: .none, begin: 3, end: 5)
		let children: ListID<TreeID> = store.treeLists.appending(
			b,
			to: store.treeLists.single(a),
		)
		let branch: TreeID = store.branch(
			grammar: grammar,
			label: "root",
			children: children,
			cursor: 9,
		)
		#expect(store[branch].begin == 1)
		#expect(store[branch].end == 5)
		#expect(store[branch].label == "root")
		#expect(store.treeLists.elements(store[branch].children) == [a, b])
	}

	@Test func 子のない枝はcursorの点になる() throws {
		var store: Store = .init()
		let branch: TreeID = store.branch(
			grammar: .init(rawValue: 0),
			label: "#nil",
			children: .empty,
			cursor: 4,
		)
		#expect(store[branch].begin == 4)
		#expect(store[branch].end == 4)
	}

	@Test func 同じ形の木は同じ番号になる() throws {
		var store: Store = .init()
		let grammar: GrammarID = .init(rawValue: 0)
		let a: TreeID = store.leaf(grammar: grammar, label: "A", begin: 0, end: 1)
		let b: TreeID = store.leaf(grammar: grammar, label: "A", begin: 0, end: 1)
		let c: TreeID = store.leaf(grammar: grammar, label: "B", begin: 0, end: 1)
		#expect(a == b)
		#expect(a != c)
	}

}
