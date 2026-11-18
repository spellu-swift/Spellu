import SpelluCore
import SpelluLex


// 対象API: Branchの初期化・precedence・body、AnyOf、AnyOfBuilderの
// buildExpression、buildBlock、buildPartialBlockの全オーバーロード。
// 構文・字句のChoiceOfを同じブロックにネストしても区別できること。
// 空・単独・配列・混在について、候補の順序と優先値と本体を確認する。
@Suite struct AnyOfBuilderTests {

	@Test func Branchは指定した優先値と構文本体を保持する() throws {
		var calls: Int = 0
		let branch: Branch = .init(17) {
			let _: Void = { calls += 1 }()
			Sequence(label: "first") {}
			Sequence(label: "second") {}
		}
		#expect(calls == 1)
		#expect(branch.precedence.rawValue == 17)
		#expect(branch.body.count == 2)
		guard
			case let .sequence(first, firstBody) = branch.body[0],
			case let .sequence(second, secondBody) = branch.body[1]
		else {
			Issue.record("Branchの本体が保持されていない")
			return
		}
		#expect(firstBody.isEmpty)
		#expect(secondBody.isEmpty)
		#expect(first == "first")
		#expect(second == "second")
	}

	@Test func 空のAnyOfは空のchoiceを生成する() {
		let syntax: SyntaxIR = AnyOf {}
		guard case let .anyOf(branches) = syntax else {
			Issue.record("AnyOfはchoiceを生成する必要がある")
			return
		}
		#expect(branches.isEmpty)
	}

	@Test func 単独のBranchもchoiceとして保持する() {
		let syntax: SyntaxIR = AnyOf {
			Branch(.max) {}
		}
		guard case let .anyOf(branches) = syntax else {
			Issue.record("単独の候補でもchoiceを生成する必要がある")
			return
		}
		#expect(branches.map(\.precedence) == [.max])
		#expect(branches.first?.body.isEmpty == true)
	}

	@Test func Branchと配列を混在させても順序と本体を保持する() throws {
		let syntax: SyntaxIR = AnyOf {
			[Branch(10) { Sequence(label: "first") {} }]
			Branch(90) { Sequence(label: "second") {} }
			[Branch]()
			[
				Branch(30) { Sequence(label: "third") {} },
				Branch(20) { Sequence(label: "fourth") {} },
			]
			Branch(0) { Sequence(label: "last") {} }
		}
		guard case let .anyOf(branches) = syntax else {
			Issue.record("AnyOfはchoiceを生成する必要がある")
			return
		}
		#expect(branches.map(\.precedence.rawValue) == [10, 90, 30, 20, 0])
		var labels: [Label] = []
		for branch: Branch in branches {
			#expect(branch.body.count == 1)
			let ir: SyntaxIR = try #require(branch.body.first)
			guard case let .sequence(label, body) = ir else {
				Issue.record("候補の本体が保持されていない")
				return
			}
			#expect(body.isEmpty)
			labels.append(label)
		}
		#expect(labels == ["first", "second", "third", "fourth", "last"])
	}

	@Test func 空の配列から候補を追加できる() {
		let syntax: SyntaxIR = AnyOf {
			[Branch]()
			Branch(.min) {}
			Branch(.max) {}
		}
		guard case let .anyOf(branches) = syntax else {
			Issue.record("AnyOfはchoiceを生成する必要がある")
			return
		}
		#expect(branches.map(\.precedence) == [.min, .max])
	}

	@Test func ChoiceOfは構文候補を定義順に保持する() {
		let syntax: SyntaxIR = ChoiceOf {
			"first"
			"second"
		}
		guard case let .choiceOf(candidates) = syntax else {
			Issue.record("構文ChoiceOfはorderedChoiceを生成する必要がある")
			return
		}
		#expect(candidates.count == 2)
	}

	@Test func ChoiceOfを構文と字句でネストして使える() {
		let syntax: Syntax = .init {
			AnyOf {
				Branch(.high) {
					ChoiceOf {
						Token { ChoiceOf { "ab"; "a" }; "b" }
						Token("fallback")
					}
				}
			}
		}
		guard
			case let .anyOf(branches) = syntax.ir[0],
			case let .choiceOf(candidates) = branches[0].body[0],
			case let .token(_, pattern, _, _) = candidates[0],
			case let .sequence(patterns) = pattern.factor,
			case let .alternative(alternatives) = patterns[0].factor
		else {
			Issue.record("構文と字句のChoiceOfが区別されていない")
			return
		}
		#expect(branches[0].precedence == .high)
		#expect(candidates.count == 2)
		#expect(patterns.count == 2)
		let strings: [String] = alternatives.compactMap {
			if case let .string(string) = $0.factor { string } else { nil }
		}
		#expect(strings == ["ab", "a"])
	}

	@Test func AnyOfはSyntaxの構成要素として使える() {
		let syntax: Syntax = .init {
			"before"
			AnyOf {
				Branch(.low) { "a" }
				Branch(.high) { "b" }
			}
			"after"
		}
		#expect(syntax.ir.count == 3)
		guard case let .anyOf(branches) = syntax.ir[1] else {
			Issue.record("Syntax内のAnyOfが保持されていない")
			return
		}
		#expect(branches.map(\.precedence) == [.low, .high])
	}
}
