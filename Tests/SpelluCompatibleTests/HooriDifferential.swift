import Foundation
import Spellu


/// 乱数で作った小さな文法と入力について、Interpreter・Sakuya・Hooriの結果を比べる。
///
/// 例示のテストでは拾いにくい、候補の同一性や空の反復などの差を見つけるための検査。
/// 環境変数 `SPELLU_HOORI_DIFFERENTIAL` で文法の個数を増やせる。
@Suite struct HooriDifferentialTests {

	@Test func 乱数の文法でHooriの結果がv4とSakuyaに一致する() throws {
		let count: Int
		= ProcessInfo.processInfo.environment["SPELLU_HOORI_DIFFERENTIAL"]
			.flatMap(Int.init) ?? 300

		let offset: UInt64
		= ProcessInfo.processInfo.environment["SPELLU_HOORI_SEED"]
			.flatMap(UInt64.init) ?? 0

		var compared: Int = 0
		var succeeded: Int = 0
		var ambiguous: Int = 0
		var skipped: Int = 0
		var split: Int = 0
		var mismatches: [String] = []

		for seed: UInt64 in 0..<UInt64(count) {
			var fuzzer: GrammarFuzzer
			= .init(seed: seed + offset)

			// 半分の文法では、自動Triviaの範囲が出る構文Triviaの規則を使う。
			let grammar: SpelluGrammar
			= fuzzer.grammar(spaceAsTriviaRule: seed.isMultiple(of: 2))

			let interpreter: Spellu
			let hoori: Spellu
			let sakuya: Spellu

			do {
				interpreter = try Spellu(engine: .interpreter).input(grammar)
				hoori = try Spellu(engine: .hoori).input(grammar)
				sakuya = try Spellu(engine: .sakuya).input(grammar)
			}
			catch {
				skipped += 1
				continue
			}

			for _ in 0..<6 {
				let input: String
				= fuzzer.input()

				for method: MatchMethod in [.whole, .prefix] {
					let reference: String
					= outcome(interpreter, input, method)

					let actual: String
					= outcome(hoori, input, method)

					let other: String
					= outcome(sakuya, input, method)

					// 作業量の計数はエンジンごとに異なるので、上限で止まったものは比べない。
					if [reference, other, actual].contains(where: {
						$0.hasPrefix("safetyStop")
					}) {
						skipped += 1
						continue
					}

					if reference != other {
						split += 1
						continue
					}

					compared += 1

					if reference.hasPrefix("ambiguousPath") {
						ambiguous += 1
					}
					else if !reference.hasPrefix("unexpected") {
						succeeded += 1
					}

					if actual != reference {
						mismatches.append(
							"""
							seed=\(seed + offset) method=\(method) \
							input=\(input.debugDescription)
							grammar: \(fuzzer.description)
							Interpreter: \(reference)
							Hoori: \(actual)
							Sakuya: \(other)
							""",
						)
					}
				}
			}
		}

		print(
			"HOORI_DIFFERENTIAL compared=\(compared) succeeded=\(succeeded) "
				+ "ambiguous=\(ambiguous) skipped=\(skipped) "
				+ "split=\(split) mismatches=\(mismatches.count)",
		)

		for mismatch: String in mismatches.prefix(12) {
			print(mismatch)
		}

		#expect(mismatches.isEmpty)
	}

	private func outcome(
		_ parser: Spellu,
		_ input: String,
		_ method: MatchMethod,
	) -> String {
		do {
			let source: Source
			= .temporary(input)

			let asis: SourceTree
			= try parser.parse(source, method: method, strategy: .asis)

			let compact: SourceTree
			= try parser.parse(source, method: method, strategy: .compact)

			let trivia: [String]
			= asis.trivia.map { "\($0.grammar ?? "")\($0.range)" }

			return "\(asis.root.renderTree().asText)\n"
				+ "\(compact.root.renderTree().asText)\n\(trivia)"
		}
		catch let error as SpelluError {
			switch error {
				case let .unexpected(_, offset, _, _, expects):
					return "unexpected(\(offset), \(expects))"
				case let .safetyStop(reason):
					return "safetyStop(\(reason))"
				default:
					return "\(error)"
			}
		}
		catch {
			return "\(error)"
		}
	}

}


/// シード固定の乱数で文法と入力を作る。InterpreterDifferentialTestsでも使う。
struct GrammarFuzzer {

	private var state: UInt64
	private var identifier: Int64 = 1
	private var rules: [String] = []
	private var hasTrivia: Bool = false
	private(set) var description: String = ""

	init(
		seed: UInt64,
	) {
		state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x1234_5678
	}

	private mutating func next() -> UInt64 {
		state = state &+ 0x9E37_79B9_7F4A_7C15

		var z: UInt64 = state
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB

		return z ^ (z >> 31)
	}

	private mutating func pick(
		_ count: Int,
	) -> Int {
		Int(next() % UInt64(count))
	}

	private mutating func chance(
		_ percent: Int,
	) -> Bool {
		pick(100) < percent
	}

	mutating func input() -> String {
		let alphabet: [Character]
		= hasTrivia ? ["a", "b", "c", " "] : ["a", "b", "c"]

		let length: Int
		= pick(7)

		return String((0..<length).map { _ in alphabet[pick(alphabet.count)] })
	}

	mutating func grammar(spaceAsTriviaRule: Bool = false) -> SpelluGrammar {
		let count: Int
		= 1 + pick(3)

		rules = (0..<count).map { "r\($0)" }

		var spaces: [SpacePattern] = []
		var trivia: [String] = []

		switch pick(5) {
			case 0:
				if spaceAsTriviaRule {
					trivia = ["space"]
				}
				else {
					spaces = [.space]
				}
				hasTrivia = true
			case 1:
				spaces = [.token(.string("c"))]
				hasTrivia = false
			case 2 where spaceAsTriviaRule:
				// 読み方が複数ある構文Trivia。字句Triviaをはさむので範囲は隣接しない。
				spaces = [.token(.string("c"))]
				trivia = ["space", "spaced"]
				hasTrivia = true
			default:
				break
		}

		var definitions: [(
			name: String,
			label: Label,
			expose: Bool,
			syntax: Syntax,
		)] = []

		for (index, name) in rules.enumerated() {
			let body: [SyntaxIR]
			= sequence(depth: 3)

			description += "\(name) = \(body)\n"

			definitions.append(
				(
					name: name,
					label: .labeled(name),
					expose: index == 0,
					syntax: Syntax { body },
				),
			)
		}

		for (name, text): (String, String) in [("space", " "), ("spaced", " c ")]
			where trivia.contains(name)
		{
			definitions.append((name, .none, false, Syntax { Fragment(text) }))
		}

		description += "spaces = \(spaces), trivia = \(trivia)\n"

		return .init(
			name: "F",
			spaces: spaces,
			trivia: trivia,
			rules: definitions,
		)
	}

	private mutating func sequence(
		depth: Int,
	) -> [SyntaxIR] {
		let count: Int
		= 1 + pick(3)

		return (0..<count).map { _ in syntax(depth: depth) }
	}

	private mutating func amount() -> Amount {
		switch pick(7) {
			case 0: .zeroOrMore
			case 1: .oneOrMore
			case 2: .zeroOrOne
			case 3: .exactly(2)
			case 4: .range(1, 2)
			case 5: .nOrMore(2)
			default: .upToN(2)
		}
	}

	private mutating func behavior() -> SyntaxRepetitionBehavior {
		chance(70) ? .eager : .reluctant
	}

	private mutating func token(
		_ pattern: TokenIR,
		spacious: Bool,
		label: Label = .none,
		tag: String? = nil,
	) -> SyntaxIR {
		return .token(
			label,
			pattern,
			spacious: spacious,
			tag: tag,
		)
	}

	private mutating func leaf() -> SyntaxIR {
		let spacious: Bool
		= hasTrivia && chance(50)

		let literal: String
		= ["a", "b", "ab", "c", ""][pick(5)]

		switch pick(10) {
			case 0, 1, 2, 3:
				return token(.string(literal), spacious: spacious)
			case 4:
				return token(
					.string(literal),
					spacious: spacious,
					label: chance(50) ? "x" : "y",
				)
			case 5:
				return token(
					.alternative(
						[.string("a"), .string("b")],
						amount: chance(50) ? .oneOrMore : .zeroOrMore,
					),
					spacious: spacious,
				)
			case 6:
				return token(
					.string(literal),
					spacious: spacious,
					tag: chance(50) ? "s" : "t",
				)
			case 7:
				return .tokenref(
					tag: chance(50) ? "s" : "t",
					spacious: spacious,
				)
			case 8:
				return .word(
					.none,
					.alternative(
						[.string("a"), .string("b")],
						amount: .oneOrMore,
					),
					["a", "ab", "ba"],
					caseInsensitive: chance(30),
				)
			default:
				return .ruleref(nil, rules[pick(rules.count)])
		}
	}

	private mutating func syntax(
		depth: Int,
	) -> SyntaxIR {
		if depth <= 0 || chance(35) {
			return leaf()
		}

		let inner: Int
		= depth - 1

		switch pick(12) {
			case 0:
				return .choiceOf(sequence(depth: inner))
			case 1:
				let count: Int
				= 1 + pick(3)

				var branches: [Branch] = []

				for _ in 0..<count {
					let precedence: Precedence
					= [.low, .middle, .high][pick(3)]

					let body: [SyntaxIR]
					= sequence(depth: inner)

					branches.append(Branch(precedence) { body })
				}

				return .anyOf(branches)
			case 2:
				return .optional(sequence(depth: inner))
			case 3:
				return .repeat(
					sequence(depth: inner),
					amount(),
					behavior: behavior(),
				)
			case 4:
				return .list(
					sequence(depth: inner),
					sequence(depth: inner),
					lastSeparator: chance(50) ? .allow : .deny,
					amount(),
				)
			case 5:
				return .enclosure(
					sequence(depth: inner),
					amount: amount(),
					behavior: behavior(),
					opener: sequence(depth: inner),
					closer: sequence(depth: inner),
				)
			case 6:
				return .sequence(
					chance(50) ? .none : "g",
					sequence(depth: inner),
				)
			case 7:
				return .capture(sequence(depth: inner))
			case 8:
				return .atomic(sequence(depth: inner))
			case 9:
				return .relabel(
					label: "re",
					syntax(depth: inner),
				)
			case 10:
				return hasTrivia ? .trivia : leaf()
			default:
				return .choiceOf(sequence(depth: inner))
		}
	}

}
