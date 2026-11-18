import Foundation
import Spellu


/// 乱数で作った小さな文法と入力について、Interpreter（v5）とHooriの結果を比べる。
///
/// Interpreterは選択の規則をHooriと同じにしている。対応していない構文を含む文法は
/// 準備時に拒否されるので、比べずに数えるだけにする。段階が進むと比べる文法が増える。
/// 環境変数 `SPELLU_INTERPRETER_DIFFERENTIAL` で文法の個数、
/// `SPELLU_INTERPRETER_SEED` で乱数の範囲を変えられる。
@Suite struct InterpreterDifferentialTests {

	@Test func 乱数の文法でInterpreterの結果がHooriに一致する() throws {
		let count: Int
		= ProcessInfo.processInfo.environment["SPELLU_INTERPRETER_DIFFERENTIAL"]
			.flatMap(Int.init) ?? 3000

		let offset: UInt64
		= ProcessInfo.processInfo.environment["SPELLU_INTERPRETER_SEED"]
			.flatMap(UInt64.init) ?? 0

		var compared: Int = 0
		var succeeded: Int = 0
		var ambiguous: Int = 0
		var unsupported: Int = 0
		var skipped: Int = 0
		var stoppedHoori: Int = 0
		var stoppedInterpreter: Int = 0
		var stoppedBoth: Int = 0
		var interpreterStops: [String] = []
		var mismatches: [String] = []

		for seed: UInt64 in 0..<UInt64(count) {
			var fuzzer: GrammarFuzzer
			= .init(seed: seed + offset)

			let grammar: SpelluGrammar
			= fuzzer.grammar()

			let hoori: Spellu
			let interpreter: Spellu

			do {
				hoori = try Spellu(engine: .hoori).input(grammar)
			}
			catch {
				skipped += 1
				continue
			}

			do {
				interpreter = try Spellu(engine: .interpreter).input(grammar)
			}
			catch SpelluError.unsupportedSyntax {
				unsupported += 1
				continue
			}

			for _ in 0..<6 {
				let input: String
				= fuzzer.input()

				for method: MatchMethod in [.whole, .prefix] {
					let reference: String
					= outcome(hoori, input, method)

					let actual: String
					= outcome(interpreter, input, method)

					// 作業量の計数はエンジンごとに異なるので、上限で止まったものは比べない。
					// Interpreterだけが止まったものは、落ちにくさを見るために別に数える。
					let hooriStopped: Bool
					= reference.hasPrefix("safetyStop")

					let interpreterStopped: Bool
					= actual.hasPrefix("safetyStop")

					switch (hooriStopped, interpreterStopped) {
						case (true, true):
							stoppedBoth += 1
							continue

						case (true, false):
							stoppedHoori += 1
							continue

						case (false, true):
							stoppedInterpreter += 1

							if interpreterStops.count < 12 {
								interpreterStops.append(
									"""
									seed=\(seed + offset) method=\(method) \
									input=\(input.debugDescription)
									grammar: \(fuzzer.description)
									Interpreter: \(actual)
									""",
								)
							}

							continue

						case (false, false):
							break
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
							Hoori: \(reference)
							Interpreter: \(actual)
							""",
						)
					}
				}
			}
		}

		print(
			"INTERPRETER_DIFFERENTIAL compared=\(compared) "
				+ "succeeded=\(succeeded) ambiguous=\(ambiguous) "
				+ "unsupported=\(unsupported) skipped=\(skipped) "
				+ "stopped(hoori=\(stoppedHoori) "
				+ "interpreter=\(stoppedInterpreter) both=\(stoppedBoth)) "
				+ "mismatches=\(mismatches.count)",
		)

		for stop: String in interpreterStops {
			print(stop)
		}

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
			let asis: SourceNode
			= try parser.parse(input, method: method, strategy: .asis)

			let compact: SourceNode
			= try parser.parse(input, method: method, strategy: .compact)

			return "\(asis.renderTree().asText)\n\(compact.renderTree().asText)"
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


/// 差分テストで差が出た乱数の文法を固定して、Interpreterの結果をHooriと比べる。
@Suite struct InterpreterDifferentialRegressionTests {

	/// - 20710：空のまま自分自身を呼ぶ再帰。循環を結果でだけ調べる。
	/// - 21452：Listの選択肢ごとに複製した要素を、同じ呼び出しとして扱う。
	@Test(arguments: [20710, 21452] as [UInt64])
	func 差が出た乱数の文法でHooriに一致する(
		seed: UInt64,
	) throws {
		var fuzzer: GrammarFuzzer
		= .init(seed: seed)

		let grammar: SpelluGrammar
		= fuzzer.grammar()

		let hoori: Spellu
		= try Spellu(engine: .hoori).input(grammar)

		let interpreter: Spellu
		= try Spellu(engine: .interpreter).input(grammar)

		for _ in 0..<6 {
			let input: String
			= fuzzer.input()

			for method: MatchMethod in [.whole, .prefix] {
				#expect(
					outcome(interpreter, input, method)
						== outcome(hoori, input, method),
					"seed=\(seed) method=\(method) input=\(input.debugDescription)",
				)
			}
		}
	}

	private func outcome(
		_ parser: Spellu,
		_ input: String,
		_ method: MatchMethod,
	) -> String {
		do {
			let asis: SourceTree
			= try parser.parse(.temporary(input), method: method, strategy: .asis)

			let compact: SourceTree
			= try parser.parse(.temporary(input), method: method, strategy: .compact)

			return "\(asis.root.renderTree().asText)\n\(compact.root.renderTree().asText)"
		}
		catch {
			return "\(error)"
		}
	}

}


/// 乱数で作った小さな文法と入力について、InterpreterとSakuyaの自動Triviaを比べる。
///
/// どちらも本文が成功して同じ木を返したときに、`SourceTree.trivia` の範囲と所属文法を比べる。
/// 環境変数 `SPELLU_INTERPRETER_DIFFERENTIAL` で文法の個数、
/// `SPELLU_INTERPRETER_SEED` で乱数の範囲を変えられる。
@Suite struct InterpreterTriviaDifferentialTests {

	@Test func 乱数の文法で自動TriviaがSakuyaに一致する() throws {
		let count: Int
		= ProcessInfo.processInfo.environment["SPELLU_INTERPRETER_DIFFERENTIAL"]
			.flatMap(Int.init) ?? 3000

		let offset: UInt64
		= ProcessInfo.processInfo.environment["SPELLU_INTERPRETER_SEED"]
			.flatMap(UInt64.init) ?? 0

		var compared: Int = 0
		var withTrivia: Int = 0
		var skipped: Int = 0
		var mismatches: [String] = []

		for seed: UInt64 in 0..<UInt64(count) {
			var fuzzer: GrammarFuzzer
			= .init(seed: seed + offset)

			let grammar: SpelluGrammar
			= fuzzer.grammar(spaceAsTriviaRule: true)

			guard
				let sakuya: Spellu = try? Spellu(engine: .sakuya).input(grammar),
				let interpreter: Spellu
					= try? Spellu(engine: .interpreter).input(grammar)
			else {
				skipped += 1
				continue
			}

			for _ in 0..<6 {
				let input: String
				= fuzzer.input()

				for method: MatchMethod in [.whole, .prefix] {
					// 本文が成功して同じ木を返したものだけを比べる。
					guard
						let reference: SourceTree = try? sakuya.parse(
							.temporary(input),
							method: method,
							strategy: .asis,
						),
						let actual: SourceTree = try? interpreter.parse(
							.temporary(input),
							method: method,
							strategy: .asis,
						),
						reference.root == actual.root
					else {
						skipped += 1
						continue
					}

					compared += 1

					if !reference.trivia.isEmpty {
						withTrivia += 1
					}

					if actual.trivia != reference.trivia {
						mismatches.append(
							"""
							seed=\(seed + offset) method=\(method) \
							input=\(input.debugDescription)
							grammar: \(fuzzer.description)
							Sakuya: \(reference.trivia.map { "\($0.grammar ?? "")\($0.range)" })
							Interpreter: \(actual.trivia.map { "\($0.grammar ?? "")\($0.range)" })
							""",
						)
					}
				}
			}
		}

		print(
			"INTERPRETER_TRIVIA_DIFFERENTIAL compared=\(compared) "
				+ "withTrivia=\(withTrivia) skipped=\(skipped) "
				+ "mismatches=\(mismatches.count)",
		)

		for mismatch: String in mismatches.prefix(12) {
			print(mismatch)
		}

		#expect(mismatches.isEmpty)
	}

}
