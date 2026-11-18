///
/// 後順のたどり
///
/// 子の値を先に求めてから、親の値を作る。明示スタックはこの中だけに置き、
/// 呼ぶ側は「子の一覧」と「子の値から自分の値を作る関数」だけを渡す。
/// たどる深さがどれだけあっても、Swiftの呼び出しは深くならない。
///
/// - 一度求めた値は覚えておき、同じノードでは使い回す。
/// - たどっている途中のノードにまた入ったら、循環として `cut` の値を使う。
///   循環を含む値は経路によって変わるので、覚えない。
/// - 循環を調べるのは `tracksCycle` が真のノードだけ。それ以外のノードは、
///   たどっている途中でもう一度入れる。どの循環も調べるノードを通るなら止まる。
///
struct Walk<Node : Hashable, Value> {

	private enum Task {
		case enter(Node)
		case exit(Node, count: Int)
	}

	private var memo: [Node: Value] = [:]

	init() {
	}

	mutating func value(
		of root: Node,
		children: (Node) throws -> [Node],
		combine: (Node, [Value]) throws -> Value,
		cut: (Node) throws -> Value,
		tracksCycle: (Node) -> Bool = { _ in true },
	) throws -> Value {
		var tasks: [Task] = [.enter(root)]
		var values: [(value: Value, cyclic: Bool)] = []
		var active: Set<Node> = []

		while let task: Task = tasks.popLast() {
			switch task {
				case let .enter(node):
					if let known: Value = memo[node] {
						values.append((known, false))

						continue
					}

					let tracked: Bool
					= tracksCycle(node)

					if tracked {
						if active.contains(node) {
							values.append((try cut(node), true))

							continue
						}

						active.insert(node)
					}

					let kids: [Node]
					= try children(node)

					tasks.append(.exit(node, count: kids.count))
					tasks.append(contentsOf: kids.reversed().map { .enter($0) })

				case let .exit(node, count):
					let inputs: [(value: Value, cyclic: Bool)]
					= Array(values.suffix(count))

					values.removeLast(count)

					if tracksCycle(node) {
						active.remove(node)
					}

					// キーパス（`\.value`）はDebugビルドで遅いので、クロージャで取り出す。
					let value: Value
					= try combine(node, inputs.map { $0.value })

					let cyclic: Bool
					= inputs.contains { $0.cyclic }

					if !cyclic {
						memo[node] = value
					}

					values.append((value, cyclic))
			}
		}

		return values[0].value
	}

}
