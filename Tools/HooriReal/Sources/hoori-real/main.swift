import Foundation
import Spellu
import XML
import HTML
import Markdown
import ECMAScript
import CSS
import Lua
import EBNF

// 実文法の入力を各エンジンで解析し、木の一致と時間を比べる。
// 使い方: hoori-real <suite> [maxInputs] [engines]

func fingerprint(_ node: SourceNode) -> UInt64 {
	var hash: UInt64 = 0xcbf29ce484222325
	func mix(_ value: UInt64) { hash = (hash ^ value) &* 0x100000001b3 }
	var stack: [SourceNode] = [node]
	while let current = stack.popLast() {
		mix(UInt64(current.begin))
		mix(UInt64(current.end))
		mix(UInt64(current.parts.count))
		for byte in (current.label.string ?? "").utf8 { mix(UInt64(byte)) }
		stack.append(contentsOf: current.parts.reversed())
	}
	return hash
}

enum Outcome: Equatable { case tree(UInt64), failure(String), stop(String) }

struct Runner {
	let name: String
	let parser: Spellu
	var seconds: Double = 0
	var success: Int = 0
	var failure: Int = 0
	var stops: Int = 0
}

let suite = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "xml"
let maxInputs = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? .max : .max
let names = CommandLine.arguments.count > 3
	? CommandLine.arguments[3].split(separator: ",").map(String.init)
	: ["hoori", "interpreter", "sakuya"]

let grammars: [SpelluGrammar]
switch suite {
	case "xml": grammars = [XMLGrammar.default.grammar()]
	case "html": grammars = [HTMLGrammar.default.grammar(), HTMLTextGrammar.default.grammar()]
	case "markdown": grammars = [MarkdownGrammar.default.grammar(), MarkdownHTMLGrammar.default.grammar()]
	case "ecmascript": grammars = [ECMAScriptGrammar.default.grammar()]
	case "css": grammars = [CSSGrammar.default.grammar()]
	case "lua": grammars = [LuaGrammar.default.grammar()]
	case "ebnf": grammars = [EBNFGrammar.default.grammar()]
	default: fatalError("unknown suite")
}

func engine(_ name: String) -> Spellu.Engine {
	switch name {
		case "interpreter":
			return .interpreter(limits: .init(
				maxTokenRepetition: 20_000, maxBoundaryDepth: 20_000,
				maxWork: 500_000_000,
			))
		case "sakuya":
			return .sakuya(limits: .init(
				maxSyntaxRepetition: 20_000, maxTokenRepetition: 20_000,
			))
		case "hoori":
			return .hoori(limits: .init(
				maxTokenRepetition: 20_000, maxBoundaryDepth: 20_000,
				maxWork: 500_000_000,
			))
		default: fatalError("unknown engine: \(name)")
	}
}

let clock = ContinuousClock()
func seconds(_ d: Duration) -> Double {
	let c = d.components
	return Double(c.seconds) + Double(c.attoseconds) / 1e18
}

var runners: [Runner] = []
for name in names {
	let start = clock.now
	do {
		let parser = try Spellu(engine: engine(name)).input(grammars)
		print("prepare \(name): \(String(format: "%.3f", seconds(start.duration(to: clock.now)) * 1000))ms")
		runners.append(.init(name: name, parser: parser))
	}
	catch {
		print("prepare \(name) FAILED: \(error)")
	}
}

struct Input: Decodable { let name: String; let text: String }
let data = FileManager.default.contents(atPath: "/private/tmp/hoori-real-inputs/\(suite).json")!
var inputs = try JSONDecoder().decode([Input].self, from: data)
if let filter = ProcessInfo.processInfo.environment["HOORI_FILTER"] {
	inputs = inputs.filter { $0.name.contains(filter) }
}
if inputs.count > maxInputs { inputs = Array(inputs.prefix(maxInputs)) }
print("suite=\(suite) inputs=\(inputs.count) bytes=\(inputs.reduce(0) { $0 + $1.text.utf8.count })")

// エンジン同士の比較の集計
struct Pair { var same = 0, tree = 0, error = 0, onlyHoori = 0, onlyOther = 0, stopped = 0; var details: [String] = [] }
var pairs: [String: Pair] = [:]
var slowest: [(Double, String, Int)] = []

for (index, input) in inputs.enumerated() {
	let source: Source = .temporary(input.text)
	var results: [String: Outcome] = [:]
	for e in runners.indices {
		let start = clock.now
		do {
			let tree: SourceNode = try runners[e].parser.parse(source, method: .whole, strategy: .compact)
			results[runners[e].name] = .tree(fingerprint(tree))
			runners[e].success += 1
		}
		catch let error as SpelluError {
			switch error {
				case .safetyStop:
					runners[e].stops += 1
					results[runners[e].name] = .stop("\(error)")
				case let .unexpected(_, offset, _, _, expects):
					runners[e].failure += 1
					results[runners[e].name] = .failure("unexpected(\(offset),\(expects))")
				default:
					runners[e].failure += 1
					results[runners[e].name] = .failure("\(error)")
			}
		}
		let elapsed = seconds(start.duration(to: clock.now))
		runners[e].seconds += elapsed
		if runners[e].name == "hoori" { slowest.append((elapsed, input.name, input.text.utf8.count)) }
	}
	guard let actual = results["hoori"] else { continue }
	for other in runners where other.name != "hoori" {
		guard let reference = results[other.name] else { continue }
		var pair = pairs[other.name] ?? .init()
		switch (reference, actual) {
			case (.stop, _), (_, .stop):
				pair.stopped += 1
			case let (.tree(a), .tree(b)):
				if a == b { pair.same += 1 } else {
					pair.tree += 1
					if pair.details.count < 15 { pair.details.append("TREE \(input.name) (\(input.text.utf8.count)B)") }
					if ProcessInfo.processInfo.environment["HOORI_DUMP"] != nil, pair.tree <= 2 {
						print("--- \(input.name)\n\(input.text)")
						for runner in runners where runner.name == "hoori" || runner.name == other.name {
							if let tree: SourceNode = try? runner.parser.parse(source, method: .whole, strategy: .asis) {
								print("[\(runner.name)]\n\(tree.renderTree().asText)")
							}
						}
					}
				}
			case let (.failure(a), .failure(b)):
				if a == b { pair.same += 1 } else {
					pair.error += 1
					if pair.details.count < 15 { pair.details.append("ERROR \(input.name) \(other.name)=\(a.prefix(110)) hoori=\(b.prefix(110))") }
				}
			case let (.failure(a), .tree):
				pair.onlyHoori += 1
				if pair.details.count < 15 { pair.details.append("HOORI_ONLY \(input.name) (\(input.text.utf8.count)B) \(other.name)=\(a.prefix(150))") }
			case let (.tree, .failure(b)):
				pair.onlyOther += 1
				if pair.details.count < 15 { pair.details.append("OTHER_ONLY \(input.name) (\(input.text.utf8.count)B) hoori=\(b.prefix(150))") }
			default:
				break
		}
		pairs[other.name] = pair
	}
	if index % 1000 == 999 { print("progress \(index + 1)/\(inputs.count)"); fflush(stdout) }
}

print("=== engines")
for e in runners {
	print("\(e.name): success=\(e.success) failure=\(e.failure) safetyStop=\(e.stops) total=\(String(format: "%.3f", e.seconds))s")
}
print("=== hoori vs others")
for (name, pair) in pairs.sorted(by: { $0.key < $1.key }) {
	print("\(name): same=\(pair.same) treeDiff=\(pair.tree) errorDiff=\(pair.error) hooriOnly=\(pair.onlyHoori) otherOnly=\(pair.onlyOther) stopped/skipped=\(pair.stopped)")
	for line in pair.details { print("  \(line)") }
}
print("slowest hoori:")
for (s, n, b) in slowest.sorted(by: { $0.0 > $1.0 }).prefix(5) { print(String(format: "%.4fs %7dB %@", s, b, n)) }
