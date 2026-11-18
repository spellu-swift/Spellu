@testable import SpelluCore


struct SourceNodeTests {
	
	
	static let source: Source = .temporary("a b c")
	

	let data: SourceNode = .init(
		grammar: nil,
		label: .none,
		source: source,
		begin: 0, end: 5,
		parts: [
			SourceNode(
				grammar: "Foo",
				label: "root",
				source: source,
				begin: 0, end: 5,
				parts: [
					SourceNode(
						grammar: "Foo",
						label: "tokenA",
						source: source,
						begin: 0, end: 1
					),
					SourceNode(
						grammar: "Bar",
						label: "tokenB",
						source: source,
						begin: 2, end: 3
					),
					SourceNode(
						grammar: nil,
						label: "tokenC",
						source: source,
						begin: 4, end: 5
					),
				]
			),
		]
	)
	
	
	@Test func query_label() async throws {
		#expect(data.query(selector: "root")?.string == "a b c")
		#expect(data.query(selector: "/root")?.string == "a b c")
		#expect(data.query(selector: "/>root")?.string == "a b c")
		#expect(data.query(selector: "/>>root")?.string == "a b c")
		
		#expect(data.query(selector: "tokenA")?.string == "a")
		#expect(data.query(selector: "/tokenA")?.string == nil)
		#expect(data.query(selector: "/>tokenA")?.string == "a")
		#expect(data.query(selector: "/>>tokenA")?.string == "a")
		#expect(data.query(selector: "Foo:tokenA")?.string == "a")
		#expect(data.query(selector: "Bar:tokenA")?.string == nil)

		#expect(data.query(selector: "tokenB")?.string == "b")
		#expect(data.query(selector: "/tokenB")?.string == nil)
		#expect(data.query(selector: "/>tokenB")?.string == "b")
		#expect(data.query(selector: "/>>tokenB")?.string == "b")
		#expect(data.query(selector: "Foo:tokenB")?.string == nil)
		#expect(data.query(selector: "Bar:tokenB")?.string == "b")

		#expect(data.query(selector: "tokenC")?.string == "c")
		#expect(data.query(selector: "/tokenC")?.string == nil)
		#expect(data.query(selector: "/>tokenC")?.string == "c")
		#expect(data.query(selector: "/>>tokenC")?.string == "c")
		#expect(data.query(selector: "Foo:tokenC")?.string == nil)
		#expect(data.query(selector: "Bar:tokenC")?.string == nil)
	}

	
	@Test func query_label_label() async throws {
		#expect(data.query(selector: "/root tokenA")?.string == "a")
		#expect(data.query(selector: "/root /tokenA")?.string == "a")
		#expect(data.query(selector: "/root />tokenA")?.string == "a")
		#expect(data.query(selector: "/root />>tokenA")?.string == "a")
	}
	
	
	@Test func query_finds_child_in_later_branch() {
		let child = SourceNode(label: "child", source: Self.source, begin: 0, end: 1)
		let branches = [
			SourceNode(label: "branch", source: Self.source, begin: 0, end: 0),
			SourceNode(label: "branch", source: Self.source, begin: 0, end: 1, parts: [child]),
		]
		let root = SourceNode(label: "root", source: Self.source, begin: 0, end: 1, parts: branches)

		#expect(root.query(selector: "/branch /child") == child)
		#expect(root.query(selector: "/branch /*") == child)
		#expect(branches.query(selector: "/child") == child)
	}

	@Test func query_limit_applies_to_final_results() {
		let child = SourceNode(label: "child", source: Self.source, begin: 0, end: 1)
		let branch = SourceNode(label: "branch", source: Self.source, begin: 0, end: 1, parts: [child])
		let root = SourceNode(label: "root", source: Self.source, begin: 0, end: 1, parts: [branch, branch])

		#expect(root.queryAll(selector: "/branch /child", limit: 1) == [child])
		#expect(root.queryAll(selector: "/branch /child", limit: 0).isEmpty)
	}

	@Test func walk_visits_leaf_once() {
		let leaf = SourceNode(label: "root", source: Self.source, begin: 0, end: 1)
		var visited: [SourceNode] = []

		leaf.walk { visited.append($0) }

		#expect(visited == [leaf])
	}

	@Test func walk_visits_each_node_once_in_preorder() {
		let grandchild = SourceNode(label: "grandchild", source: Self.source, begin: 0, end: 1)
		let first = SourceNode(label: "first", source: Self.source, begin: 0, end: 1, parts: [grandchild])
		let second = SourceNode(label: "second", source: Self.source, begin: 2, end: 3)
		let root = SourceNode(label: "root", source: Self.source, begin: 0, end: 3, parts: [first, second])
		var visited: [SourceNode] = []

		root.walk { visited.append($0) }

		#expect(visited == [root, first, grandchild, second])
	}

	@Test func flatten_returns_leaf_nodes_in_tree_order() {
		let first = SourceNode(label: "first", source: Self.source, begin: 0, end: 1)
		let second = SourceNode(label: "second", source: Self.source, begin: 2, end: 3)
		let third = SourceNode(label: "third", source: Self.source, begin: 4, end: 5)
		let branch = SourceNode(label: "branch", source: Self.source, begin: 0, end: 3, parts: [first, second])
		let root = SourceNode(label: "root", source: Self.source, begin: 0, end: 5, parts: [branch, third])

		#expect(root.flatten == [first, second, third])
	}

	@Test func flatten_returns_a_leaf_node() {
		let leaf = SourceNode(label: "leaf", source: Self.source, begin: 0, end: 1)

		#expect(leaf.flatten == [leaf])
	}

	@Test func flatten_returns_an_empty_leaf_node() {
		let leaf = SourceNode(label: "empty", source: Self.source, begin: 0, end: 0)

		#expect(leaf.flatten == [leaf])
	}

}
