@testable import SpelluHoori
import SpelluCore


// API観点：ModelBuilderが作る平坦な文法表の形と、KeyTableの動作を確認する。
@Suite struct HooriModelTests {

	@Test func 暗黙の連接は右辺へ平坦化する() throws {
		let model: GrammarModel = try makeModel {
			Fragment("a")
			Fragment("b")
		}
		let rule: GrammarModel.Rule = model.rules[0]
		let range: Range<Int32> = model.nonterminals[Int(rule.nonterminal)].productions

		#expect(range.count == 1)

		let production: GrammarModel.Production
		= model.productions[Int(model.productionOrder[Int(range.lowerBound)])]

		guard
			case .lexeme = model.symbols[Int(production.first)],
			case .lexeme = model.symbols[Int(production.first) + 1],
			case .end = model.symbols[Int(production.first) + 2]
		else {
			Issue.record("字句二つと終端が並んでいない")

			return
		}
	}

	@Test func 本体直下の選択は順位付きの生成規則になる() throws {
		let model: GrammarModel = try makeModel {
			ChoiceOf {
				Fragment("a")
				Fragment("b")
				Fragment("c")
			}
		}
		let range: Range<Int32>
		= model.nonterminals[Int(model.rules[0].nonterminal)].productions

		let ranks: [Int32] = range.map {
			model.productions[Int(model.productionOrder[Int($0)])].rank
		}

		#expect(ranks == [2, 1, 0])
	}

	@Test func 同じ字句は走査クラスを共有する() throws {
		let model: GrammarModel = try makeModel {
			Fragment(label: "x", "a")
			Fragment(label: "y", "a")
			Fragment("b")
		}

		#expect(model.lexemes.count == 3)
		#expect(model.scanClasses.count == 2)
		#expect(model.lexemes[0].scanClass == model.lexemes[1].scanClass)
		#expect(model.lexemes[0].atom != model.lexemes[1].atom)
	}

	@Test func 空にならない本文の空の回は予測しない() throws {
		let required: GrammarModel = try makeModel {
			Repeat { Fragment("a") }
		}
		let nullable: GrammarModel = try makeModel {
			Repeat { Optional { Fragment("a") } }
		}

		#expect(finalProductions(required) == 0)
		#expect(finalProductions(nullable) == 1)
	}

	@Test func 有限の反復は回数ごとの前半へ展開する() throws {
		let model: GrammarModel = try makeModel {
			Repeat(1...3) { Fragment("a") }
		}
		let prefixes: Int = model.nonterminals.filter {
			if case .loopPrefix = $0.kind { true } else { false }
		}.count

		#expect(prefixes == 4)
	}

	@Test func KeyTableは値を登録して既存の値を返す() {
		var table: KeyTable = .init()
		let key: KeyTable.Key = .init(high: 1, low: 2)

		#expect(table.find(key) == nil)
		#expect(table.insert(key, value: 7) == nil)
		#expect(table.insert(key, value: 8) == 7)
		#expect(table.find(key) == 7)
	}

	@Test func KeyTableは拡張しても値を保持する() {
		var table: KeyTable = .init()

		for index: UInt64 in 0..<1000 {
			#expect(table.insert(.init(high: index, low: index * 3), value: Int32(index)) == nil)
		}

		for index: UInt64 in 0..<1000 {
			#expect(table.find(.init(high: index, low: index * 3)) == Int32(index))
		}

		#expect(table.find(.init(high: 1000, low: 0)) == nil)
	}

}


private func finalProductions(
	_ model: GrammarModel,
) -> Int {
	model.productionOrder.filter {
		if case .final = model.productions[Int($0)].action { true } else { false }
	}.count
}

private func makeModel(
	@SyntaxBuilder _ body: () -> [SyntaxIR],
) throws -> GrammarModel {
	var builder: ModelBuilder = .init()

	return try builder.build(
		[
			.init(
				name: "S",
				spaces: [],
				trivia: [],
				rules: [("root", "root", true, Syntax(body))],
			),
		],
	)
}
