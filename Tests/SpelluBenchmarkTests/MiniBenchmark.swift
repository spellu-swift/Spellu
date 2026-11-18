import Spellu


struct MiniBenchmarkInput {
	let name: String
	let pattern: String
}


func runMiniBenchmark(
	_ inputs: [MiniBenchmarkInput],
	profile: String,
	grammars: [any GrammarDeclaration],
	startRule: RuleReference,
	engines: [Spellu.Engine],
) throws {
	let setupTrials: Int = 5
	let warmups: Int = 2
	let parseTrials: Int = 15
	let clock: ContinuousClock = .init()
	var setups: [[Duration]] = engines.map { _ in [] }
	var parsers: [Int: Spellu] = [:]

	for trial in 0..<setupTrials {
		for position in engines.indices {
			let index: Int = (position + trial) % engines.count
			let start: ContinuousClock.Instant = clock.now
			let parser: Spellu = try Spellu(engine: engines[index]).input(grammars)
			setups[index].append(start.duration(to: clock.now))
			parsers[index] = parser
		}
	}

	for index in engines.indices {
		report(profile, phase: "setup", name: "RegexGrammar", bytes: 0,
			engine: engines[index], samples: setups[index])
	}

	for input in inputs {
		let source: Source = .temporary(input.pattern)
		var samples: [[Duration]] = engines.map { _ in [] }
		for trial in 0..<(warmups + parseTrials) {
			for position in engines.indices {
				let index: Int = (position + trial) % engines.count
				let parser: Spellu = try #require(parsers[index])
				let start: ContinuousClock.Instant = clock.now
				let tree: SourceNode = try parser.parse(
					source,
					method: .whole,
					strategy: .asis,
					as: startRule,
				)
				let elapsed: Duration = start.duration(to: clock.now)
				try #require(
					tree.string == input.pattern,
					"\(engines[index]) / \(input.name)",
				)
				if trial >= warmups {
					samples[index].append(elapsed)
				}
			}
		}

		for index in engines.indices {
			report(profile, phase: "parse", name: input.name,
				bytes: input.pattern.utf8.count,
				engine: engines[index], samples: samples[index])
		}
	}
}


private func report(
	_ profile: String,
	phase: String,
	name: String,
	bytes: Int,
	engine: Spellu.Engine,
	samples: [Duration],
) {
	let sorted: [Duration] = samples.sorted()
	let median: Double = milliseconds(sorted[sorted.count / 2])
	let p90: Double = milliseconds(sorted[(sorted.count * 9 + 9) / 10 - 1])
	print("MINIBENCH|\(profile)|\(phase)|\(name)|\(bytes)|\(engine)"
		+ "|\(samples.count)|\(median)|\(p90)")
}


private func milliseconds(_ duration: Duration) -> Double {
	let components = duration.components
	return Double(components.seconds) * 1_000
		+ Double(components.attoseconds) / 1e15
}
