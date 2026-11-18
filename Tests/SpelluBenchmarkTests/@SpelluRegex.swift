import Foundation
import Spellu
import SpelluRegex


@Suite(
	.serialized,
	.enabled(if:	ProcessInfo.processInfo.environment["SPELLU_REGEX_BENCHMARK"] == "1")
)
struct SpelluRegexBenchmarkTests {

	/// Debug版で行える簡易的なベンチマークテスト
	@available(macOS 15, *)
	@Test func miniBenchmark() throws {
		let inputs: [MiniBenchmarkInput] = [
			.init(name: "literal-12", pattern: String(repeating: "a", count: 12)),
			.init(name: "literal-48", pattern: String(repeating: "a", count: 48)),
			.init(name: "class-4", pattern: classPattern(repetitions: 4)),
			.init(name: "class-16", pattern: classPattern(repetitions: 16)),
			.init(name: "nested-2", pattern: nestedPattern(depth: 2)),
			.init(name: "nested-4", pattern: nestedPattern(depth: 4)),
		]

		try runMiniBenchmark(
			inputs,
			profile: "mini",
			grammars: [RegexGrammar.default],
			startRule: RegexGrammar.$expression,
			engines: [.interpreter, .sakuya, .hoori],
		)
	}

	@available(macOS 15, *)
	@Test func largeBenchmark() throws {
		let inputs: [MiniBenchmarkInput] = [
			.init(name: "literal-192", pattern: String(repeating: "a", count: 192)),
			.init(name: "literal-384", pattern: String(repeating: "a", count: 384)),
			.init(name: "class-32", pattern: classPattern(repetitions: 32)),
			.init(name: "class-64", pattern: classPattern(repetitions: 64)),
			.init(name: "nested-12", pattern: nestedPattern(depth: 12)),
			.init(name: "nested-24", pattern: nestedPattern(depth: 24)),
		]

		try runMiniBenchmark(
			inputs,
			profile: "large",
			grammars: [RegexGrammar.default],
			startRule: RegexGrammar.$expression,
			engines: [.interpreter, .sakuya, .hoori],
		)
	}

	private func classPattern(repetitions: Int) -> String {
		"^" + String(repeating: "[abc][012]{2}", count: repetitions) + "$"
	}

	private func nestedPattern(depth: Int) -> String {
		"^" + String(repeating: "(?:", count: depth)
			+ "alpha|beta" + String(repeating: ")", count: depth) + "$"
	}

}
