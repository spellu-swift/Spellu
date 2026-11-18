import SpelluCore


// 対象API: Wordの可変長引数版と配列版。
// ラベル、パターン、語配列、フラグ、順序・重複の保持、空配列を確認する。
@Suite struct WordBuilderTests {

	@Test(arguments: [false, true])
	func 両オーバーロードが語配列の順序と重複と照合設定を保持する(
		_ insensitive: Bool,
	) {
		let rules: [SyntaxIR] = [
			Word(label: "keyword", "if", "else", "if",
				caseInsensitive: insensitive) { "x" },
			Word(label: "keyword", ["if", "else", "if"],
				caseInsensitive: insensitive) { "x" },
		]
		for rule: SyntaxIR in rules {
			guard case let .word(label, pattern, words, flag) = rule else {
				Issue.record("WordのIRではない")
				continue
			}
			#expect(label == "keyword")
			#expect(pattern == .string("x"))
			#expect(words == ["if", "else", "if"])
			#expect(flag == insensitive)
		}
	}

	@Test func 空配列と空文字を区別し既定では大小文字を区別する() {
		let rules: [SyntaxIR] = [Word() {}, Word([]) {}, Word("") {}]
		for (index, rule) in rules.enumerated() {
			guard case let .word(label, pattern, words, flag) = rule else {
				Issue.record("WordのIRではない")
				continue
			}
			#expect(label == .none)
			#expect(pattern == .sequence([]))
			#expect(words == (index == 2 ? [""] : []))
			#expect(!flag)
		}
	}

}
