@testable import SpelluInterpreter


// API観点：Walk.value(of:children:combine:cut:tracksCycle:) の後順の評価、値の使い回し、
// 循環の打ち切りと循環を含む値を覚えないこと、循環を調べないノード、深い連鎖、エラーの伝搬。
@Suite struct InterpreterWalkTests {

	@Test func 子の値を先に求めてから親の値を作る() throws {
		var walk: Walk<String, String> = .init()
		var order: [String] = []
		let value: String = try walk.value(
			of: "root",
			children: { node in
				node == "root" ? ["a", "b"] : []
			},
			combine: { node, inputs in
				order.append(node)
				return node + "(" + inputs.joined(separator: ",") + ")"
			},
			cut: { _ in "cut" },
		)
		#expect(value == "root(a(),b())")
		#expect(order == ["a", "b", "root"])
	}

	@Test func 同じノードの値を使い回す() throws {
		var walk: Walk<String, Int> = .init()
		var calls: [String: Int] = [:]
		let children: (String) -> [String] = { node in
			switch node {
				case "root": ["left", "right"]
				case "left", "right": ["shared"]
				default: []
			}
		}
		let value: Int = try walk.value(
			of: "root",
			children: children,
			combine: { node, inputs in
				calls[node, default: 0] += 1
				return inputs.reduce(1, +)
			},
			cut: { _ in 0 },
		)
		#expect(value == 5)
		#expect(calls["shared"] == 1)

		// 別の根からたどっても、覚えた値を使う。
		_ = try walk.value(
			of: "left",
			children: children,
			combine: { node, inputs in
				calls[node, default: 0] += 1
				return inputs.reduce(1, +)
			},
			cut: { _ in 0 },
		)
		#expect(calls["left"] == 1)
	}

	@Test func 循環はcutの値を使い循環を含む値は覚えない() throws {
		var walk: Walk<String, [String]> = .init()
		var calls: [String: Int] = [:]
		let children: (String) -> [String] = { node in
			switch node {
				case "a": ["b"]
				case "b": ["a"]
				default: []
			}
		}
		let combine: (String, [[String]]) -> [String] = { node, inputs in
			calls[node, default: 0] += 1
			return [node] + inputs.flatMap { $0 }
		}
		let first: [String] = try walk.value(
			of: "a",
			children: children,
			combine: combine,
			cut: { node in ["cut:" + node] },
		)
		#expect(first == ["a", "b", "cut:a"])

		// 循環を含む値は覚えていないので、もう一度作る。
		let second: [String] = try walk.value(
			of: "b",
			children: children,
			combine: combine,
			cut: { node in ["cut:" + node] },
		)
		#expect(second == ["b", "a", "cut:b"])
		#expect(calls["a"] == 2)
		#expect(calls["b"] == 2)
	}

	@Test func 深い連鎖でもSwiftの呼び出しを深くしない() throws {
		let depth: Int = 200_000
		var walk: Walk<Int, Int> = .init()
		let value: Int = try walk.value(
			of: 0,
			children: { node in node < depth ? [node + 1] : [] },
			combine: { _, inputs in (inputs.first ?? 0) + 1 },
			cut: { _ in 0 },
		)
		#expect(value == depth + 1)
	}

	@Test func 循環を調べないノードにはたどっている途中でも入り直す() throws {
		// a → b → a → b … の循環で、aだけを調べる。bは入り直し、aで打ち切る。
		var walk: Walk<String, [String]> = .init()
		let children: (String) -> [String] = { node in
			switch node {
				case "a": ["b"]
				case "b": ["a"]
				default: []
			}
		}
		let value: [String] = try walk.value(
			of: "b",
			children: children,
			combine: { node, inputs in [node] + inputs.flatMap { $0 } },
			cut: { node in ["cut:" + node] },
			tracksCycle: { $0 == "a" },
		)
		#expect(value == ["b", "a", "b", "cut:a"])
	}

	@Test func 関数のエラーを呼び出し元へ伝える() throws {
		struct Failure : Error, Equatable {}
		#expect(throws: Failure()) {
			var walk: Walk<Int, Int> = .init()
			return try walk.value(
				of: 0,
				children: { node in node == 0 ? [1] : [] },
				combine: { node, _ in
					if node == 1 { throw Failure() }
					return 0
				},
				cut: { _ in 0 },
			)
		}
		#expect(throws: Failure()) {
			var walk: Walk<Int, Int> = .init()
			return try walk.value(
				of: 2,
				children: { _ in [2] },
				combine: { _, _ in 0 },
				cut: { _ in throw Failure() },
			)
		}
	}

}
