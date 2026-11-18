@testable import SpelluSakuya


// 観点：多値変数の独立性・縮約・順序・予算、旧選択との意味論の一致。
@Suite struct SakuyaSelectionDecisionTests {

	@Test func 多値の条件を積和と否定で組み合わせ順序を維持する() throws {
		let mdd: DecisionDiagram = .init(step: {})
		let x: Int = try mdd.variable(width: 3)
		let y: Int = try mdd.variable(width: 2)
		let a: Int = try mdd.equals(x, 1)
		let b: Int = try mdd.equals(y, 0)
		let formula: Int = try mdd.or(mdd.and(a, b), mdd.equals(x, 2))
		#expect(try mdd.and(a, a) == a)
		#expect(try mdd.or(a, mdd.not(a)) == 1)
		#expect(try mdd.not(mdd.not(formula)) == formula)
		#expect(try mdd.node(x, [b, b, b]) == b)
		for xv: Int in 0..<3 {
			for yv: Int in 0..<2 {
				let fixed: Int = try mdd.and(mdd.equals(x, xv), mdd.equals(y, yv))
				let possible: Bool = try mdd.and(formula, fixed) != 0
				#expect(possible == ((xv == 1 && yv == 0) || xv == 2))
			}
		}
		let assignment: [Int: Int] = try mdd.witness(formula)
		#expect(assignment[x] == 1)
		#expect(assignment[y] == 0)
		for node in mdd.nodes.dropFirst(2) {
			#expect(node.branches.allSatisfy { mdd.nodes[$0].variable > node.variable })
		}
	}

	@Test func 遅延複製の順序と条件の射影を維持する() throws {
		let mdd: DecisionDiagram = .init(step: {})
		let parent: Int = try mdd.variable(width: 3)
		let child: Int = try mdd.variable(width: 2)
		let replica: Int = try mdd.replica(of: parent)
		#expect(mdd.precedes(replica, child))
		let copy: Int = try mdd.equals(replica, 2)
		let condition: Int = try mdd.and(copy, mdd.equals(child, 1))
		#expect(try mdd.project(condition, keepingOrigins: [parent]) == copy)
		#expect(try mdd.project(condition, keepingOrigins: []) == 1)
		#expect(try mdd.and(condition, mdd.equals(parent, 0)) != 0)
		for node in mdd.nodes.dropFirst(2) {
			#expect(node.branches.allSatisfy {
				mdd.precedes(node.variable, mdd.nodes[$0].variable)
			})
		}
	}

	@Test func 条件演算も作業量上限で停止する() throws {
		enum Stop: Error { case budget }
		var remaining: Int = 20
		let mdd: DecisionDiagram = .init {
			remaining -= 1
			if remaining < 0 { throw Stop.budget }
		}
		let x: Int = try mdd.variable(width: 3)
		remaining = 0
		#expect(throws: Stop.budget) { try mdd.equals(x, 1) }
	}

}
