//import Foundation
//import SpelluLex
//
//
//// 対象API: TokenInputStream.match(_:engine:maxTokenRepetition:)。
//// 同じ入力・パターン・反復上限で、Programの再利用の有無も比較する。
//// 時間の大小は合否条件にせず、照合結果と入力位置が変わらないことを検査する。
//@Suite(.serialized, .enabled(if:
//	ProcessInfo.processInfo.environment["SPELLU_TOKEN_BENCHMARK"] == "1"
//))
//struct TokenEngineBenchmarkTests {
//
//	@Test func TokenEngineごとの照合時間を比較する() throws {
//		#if DEBUG
//		Issue.record("ベンチマークは -c release を指定して実行してください。")
//		return
//		#else
//		let modes: [Mode] = [.interpreter, .momojiri, .momojiriCached]
//		let samples: Int = 7
//		let specification: String?
//		= ProcessInfo.processInfo.environment["SPELLU_TOKEN_BENCHMARK_BATCHES"]
//		let batches: [Int]?
//		if let specification {
//			let values: [Int?] = specification.split(
//				separator: ",", omittingEmptySubsequences: false,
//			).map { Int($0) }
//			try #require(values.count == scenarios.count)
//			try #require(values.allSatisfy {
//				guard let count: Int = $0 else { return false }
//				return (1...65_536).contains(count)
//			})
//			batches = values.compactMap { $0 }
//		}
//		else {
//			batches = nil
//		}
//		print("TokenInputStream.match: warmup=8, samples=\(samples)")
//		print("momojiriは毎回コンパイル、momojiri_cachedはProgram再利用")
//		print("maxTokenRepetition=65535")
//		print("batch_iterations=\(specification ?? "adaptive")")
//		print(ProcessInfo.processInfo.operatingSystemVersionString)
//		print("case,input_bytes,iterations,samples,engine,median_ns,min_ns,max_ns")
//
//		for (scenarioIndex, scenario) in scenarios.enumerated() {
//			let stream: TokenInputStream = .init(input: scenario.input[...])
//			// キャッシュあり用のProgramだけを測定前に1回コンパイルする。
//			let program: TokenProgram = TokenProgramCompiler(
//				optimizeSimpleRepetitions: true,
//			).compile(scenario.pattern)
//			let expected: String.Index?
//			= scenario.succeeds ? scenario.input.endIndex : nil
//			for mode: Mode in modes {
//				#expect(runBatch(
//					scenario.pattern, stream: stream, mode: mode, program: program,
//					expected: expected, iterations: 8,
//				) == 8)
//			}
//
//			// 既存の2方式で回数を決め、キャッシュありにも同じ回数を使う。
//			// 遅い方のバッチが20ms以上になるまで、同じ回数で試行する。
//			// 短い字句の測定にも上限を設け、実行時間を抑える。
//			var iterations: Int = batches?[scenarioIndex] ?? 1
//			while batches == nil {
//				var longest: Duration = .zero
//				for mode: Mode in modes.prefix(2) {
//					let result: Measurement = measure(
//						scenario.pattern, stream: stream, mode: mode, program: program,
//						expected: expected, iterations: iterations,
//					)
//					#expect(result.correct == iterations)
//					longest = max(longest, result.duration)
//				}
//				if longest >= .milliseconds(20) || iterations >= 65_536 {
//					break
//				}
//				iterations *= 2
//			}
//
//			var timings: [[Double]] = .init(repeating: [], count: modes.count)
//			for sample: Int in 0..<samples {
//				// 測定順を循環させ、一方式が常に先になるのを避ける。
//				for step: Int in 0..<modes.count {
//					let index: Int = (sample + step) % modes.count
//					let result: Measurement = measure(
//						scenario.pattern, stream: stream, mode: modes[index],
//						program: program,
//						expected: expected, iterations: iterations,
//					)
//					#expect(result.correct == iterations)
//					let parts: (seconds: Int64, attoseconds: Int64)
//					= result.duration.components
//					let nanoseconds: Double = Double(parts.seconds) * 1e9
//						+ Double(parts.attoseconds) / 1e9
//					timings[index].append(nanoseconds / Double(iterations))
//				}
//			}
//			#expect(stream.cursor == scenario.input.startIndex)
//			for index: Int in modes.indices {
//				let values: [Double] = timings[index].sorted()
//				let statistics: String = String(
//					format: "%.0f,%.0f,%.0f",
//					values[samples / 2], values[0], values[samples - 1],
//				)
//				print("\(scenario.name),\(scenario.input.utf8.count),"
//					+ "\(iterations),\(samples),\(modes[index].rawValue),"
//					+ statistics)
//			}
//		}
//		#endif
//	}
//
//}
//
//
//private extension TokenEngineBenchmarkTests {
//
//	// Programのみ再利用し、VMは他方式と同様に照合ごとに生成する。
//	enum Mode: String {
//		case interpreter
//		case momojiri
//		case momojiriCached = "momojiri_cached"
//	}
//
//	struct Scenario {
//		let name: String
//		let pattern: TokenIR
//		let input: String
//		var succeeds: Bool = true
//	}
//
//	var scenarios: [Scenario] {
//		[
//			.init(name: "literal", pattern: .string("identifier"),
//				input: "identifier"),
//			.init(name: "identifier", pattern:
//				.character(.any("abcdefghijklmnopqrstuvwxyz_0123456789".unicodeScalars.asArray)).repeat(1...),
//				input: String(repeating: "value_123", count: 8)),
//			.init(name: "long_character_repeat", pattern:
//				.character(.any("a")).repeat(1...),
//				input: String(repeating: "a", count: 16_384)),
//			.init(name: "sequence_repeat", pattern:
//				.sequence([.string("a"), .string("b")]).repeat(1...),
//				input: String(repeating: "ab", count: 2048)),
//			.init(name: "choice_backtracking", pattern:
//				.sequence([.alternative([.string("ab"), .string("a")]), .string("b")]).repeat(1...),
//				input: String(repeating: "ab", count: 512)),
//			.init(name: "eager_backtracking", pattern:
//				.sequence([.string("a").repeat(0...), .string("ab")]),
//				input: String(repeating: "a", count: 4096) + "b"),
//			.init(name: "reluctant_repeat", pattern:
//				.sequence([.string("a").repeat(0..., behavior: .reluctant), .string("!")]),
//				input: String(repeating: "a", count: 4096) + "!"),
//			.init(name: "unicode_case_folding", pattern:
//				"kσ".ignoresCase().repeat(1...),
//				input: String(repeating: "KΣ", count: 512)),
//			.init(name: "failure_backtracking", pattern:
//				.sequence(["a".repeat(0...), .string("!")]),
//				input: String(repeating: "a", count: 4096) + "?",
//				succeeds: false),
//		]
//	}
//
//	struct Measurement {
//		let duration: Duration
//		let correct: Int
//	}
//
//	func measure(
//		_ pattern: TokenIR,
//		stream: TokenInputStream,
//		mode: Mode,
//		program: TokenProgram,
//		expected: String.Index?,
//		iterations: Int,
//	) -> Measurement {
//		var correct: Int = 0
//		let duration: Duration = ContinuousClock().measure {
//			correct = runBatch(
//				pattern, stream: stream, mode: mode, program: program,
//				expected: expected, iterations: iterations,
//			)
//		}
//		return .init(duration: duration, correct: correct)
//	}
//
//	@inline(never)
//	func runBatch(
//		_ pattern: TokenIR,
//		stream: TokenInputStream,
//		mode: Mode,
//		program: TokenProgram,
//		expected: String.Index?,
//		iterations: Int,
//	) -> Int {
//		var correct: Int = 0
//		for _ in 0..<iterations {
//			let result: TokenMatchResult
//			switch mode {
//				case .interpreter:
//					result = stream.match(
//						pattern, engine: .interpreter, maxTokenRepetition: 65_535,
//					)
//				case .momojiri:
//					result = stream.match(
//						pattern, engine: .momojiri, maxTokenRepetition: 65_535,
//					)
//				case .momojiriCached:
//					var vm: TokenVM = .init(stream: stream, maxRepetition: 65_535)
//					result = vm.match(program)
//			}
//			if result.matchedEnd == expected { correct += 1 }
//		}
//		return correct
//	}
//
//}
