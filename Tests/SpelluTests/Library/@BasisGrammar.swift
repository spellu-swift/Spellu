import Spellu


let bom = [0xEF, 0xBB, 0xBF] as [UInt8]


@Suite(.serialized)
struct BasisGrammarTests {

	@Test func bom_1() throws {
		let result: SourceNode
		= try "\u{FEFF}"
			.prefixMatch(
				on: BasisGrammar.default,
				as: \.$bom
			)

		#expect(result.label == "bom")
		#expect(result.string == "\u{FEFF}")
	}


	@Test func bom_2() throws {
		let result: SourceNode
		= try (bom.asString + "---")
			.prefixMatch(
				on: BasisGrammar.default
			) {
				Optional { BasisGrammar.$bom }
			}

		#expect(result.substring == "\u{FEFF}")
		#expect(result.parts.count == 1)
		#expect(result[0].label == "bom")
		#expect(result[0].substring == "\u{FEFF}")
	}


	@Test func bom_compact_failure() throws {
		let result = try "abc---"
			.prefixMatch(
				strategy: .compact,
				on: BasisGrammar.default,
			) {
				Optional { BasisGrammar.$bom }
			}

		#expect(result.count == 0)
		#expect(result.substring.count == 0)
	}


	@Test func bom_asis_failure() throws {
		let result = try "abc---"
			.prefixMatch(
				strategy: .asis,
				on: BasisGrammar.default,
			) {
				Optional { BasisGrammar.$bom }
			}

		#expect(result.count == 0)
		#expect(result.substring.count == 0)
	}

}
