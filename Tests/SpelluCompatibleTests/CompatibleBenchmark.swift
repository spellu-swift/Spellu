import Foundation
import Spellu
import SpelluSakuya

/// 同じ公開API・入力・木の出力方法で、生成とパースを別に計測する。
func benchmarkCompatible(
	_ engines: [Spellu.Engine],
	grammars: [SpelluGrammar],
	source: String,
	file: String,
	line: Int,
	setup: (Spellu.Engine) throws -> (Source) throws -> SourceNode
) {
	guard
		ProcessInfo.processInfo.environment["SPELLU_COMPATIBLE_BENCHMARK"]
			== "1",
		engines.contains(where: { if case .sakuya = $0 { true } else { false } }
		)
	else { return }
	let invocation: Foundation.UUID = .init()
	let input: Source = .temporary(source)
	let clock: ContinuousClock = .init()
	let pair: [Spellu.Engine] = [.interpreter, .sakuya]
	var parses: [(Source) throws -> SourceNode] = []
	for engine in pair {
		do { parses.append(try setup(engine)) } catch {
			print("BENCH_ERROR|\(invocation)|\(file)|\(line)|\(engine)|setup")
			return
		}
	}
	var parseSamples: [[Double]] = [[], [], []]
	var setupSamples: [[Double]] = [[], [], []]
	var modelSamples: [Double] = []
	var successes: [Int] = [0, 0, 0]
	var trees: [SourceNode?] = [nil, nil, nil]
	for trial in 0..<17 {
		for index in (0..<3).map({ (trial + $0) % 3 }) {
			do {
				let start = clock.now
				let parser = try setup(pair[index])
				let elapsed = microseconds(start.duration(to: clock.now))
				withExtendedLifetime(parser) {}
				if trial >= 2 { setupSamples[index].append(elapsed) }
			} catch {
				print(
					"BENCH_ERROR|\(invocation)|\(file)|\(line)|\(pair[index])|setup"
				)
				return
			}
		}
	}
	for trial in 0..<17 {
		do {
			let start = clock.now
			let model = try SpelluSakuya.Parser(grammars: grammars)
			let elapsed = microseconds(start.duration(to: clock.now))
			withExtendedLifetime(model) {}
			if trial >= 2 { modelSamples.append(elapsed) }
		} catch { return }
	}
	for trial in 0..<17 {
		for index in (0..<3).map({ (trial + $0) % 3 }) {
			let start = clock.now
			let result = Result { try parses[index](input) }
			let elapsed = microseconds(start.duration(to: clock.now))
			if trial >= 2 {
				parseSamples[index].append(elapsed)
				if case .success = result { successes[index] += 1 }
			}
			if trial == 16, case .success(let tree) = result {
				trees[index] = tree
			}
			withExtendedLifetime(result) {}
		}
	}
	let reference: String? = trees[1].map { $0.renderTree().asText }
	for index in pair.indices {
		if let tree: SourceNode = trees[index], let reference {
			let same: Bool = tree.renderTree().asText == reference
			print("BENCH_TREE|\(invocation)|\(pair[index])|\(same)")
		}
		let outcome =
			successes[index] == 15
			? "success" : successes[index] == 0 ? "failure" : "mixed"
		let key =
			"BENCH|\(invocation)|\(file)|\(line)|\(source.utf8.count)|\(pair[index])|\(outcome)"
		print(
			"\(key)|parse|\(parseSamples[index].map(String.init(describing:)).joined(separator: ","))"
		)
		print(
			"\(key)|setup|\(setupSamples[index].map(String.init(describing:)).joined(separator: ","))"
		)
		if index == 2 {
			print(
				"\(key)|model|\(modelSamples.map(String.init(describing:)).joined(separator: ","))"
			)
		}
	}
}

private func microseconds(_ duration: Duration) -> Double {
	let parts = duration.components
	return Double(parts.seconds) * 1e6 + Double(parts.attoseconds) / 1e12
}
