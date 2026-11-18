import Basis
import SpelluCore
import SpelluLex


/// 確定範囲を選択した結果。
struct Match {
	let end: Int32
	let environment: Int32
	let trees: Int32
	/// 採用した導出で読み飛ばした自動Trivia。入力の順。
	let trivia: Int32
}


/// 一回のパースの状態。入力・タグ環境・診断・作業量の寿命をここに限定する。
struct Session {

	/// タグ環境の一件。文法とtagごとに番号を割り当てる。
	struct Capture : Hashable {
		let tag: Int32
		let begin: Int32
		let end: Int32
	}

	enum Expectation {
		case token(Int32, Int32, Int32)
		case words(Int32)
		case value(Expect)
	}

	/// 走査クラスの、ある位置での照合結果。
	struct ScanEntry {
		var position: Int32 = -1
		var begin: Int32 = 0
		var end: Int32 = -1
		var failure: Int32 = 0
		var recorded: Bool = false
	}

	struct TriviaEntry {
		var position: Int32 = -1
		var end: Int32 = 0
	}

	/// 現在の位置で引いた呼び出しの控え。ハッシュ表を引く回数を減らす。
	struct CallEntry {
		var chart: Int32 = -1
		var context: UInt64 = 0
		var call: Int32 = 0
	}

	let model: GrammarModel
	let source: Source
	let limits: HooriLimits
	let upperBound: Int32

	var stream: SourceStream
	var store: DerivationStore
	var scanCache: [ScanEntry]
	var triviaCache: [TriviaEntry]
	var callCache: [CallEntry]
	var matches: [Match] = []
	var boundaryResults: KeyTable = .init()

	private var environments: [[Capture]] = [[]]
	private var environmentIDs: [[Capture]: Int32] = [[]: 0]
	private var failurePosition: Int32
	private var expectations: [Expectation] = []
	private var chartCount: Int32 = 0

	init(
		model: GrammarModel,
		source: Source,
		limits: HooriLimits,
		start: Int32,
	) {
		self.model = model
		self.source = source
		self.limits = limits
		self.upperBound = Int32(source.range.upperBound)
		self.stream = .init(
			source,
			engine: .momojiri,
			maxTokenRepetition: limits.maxTokenRepetition,
		)
		self.store = .init(budget: .init(limit: limits.maxWork))
		self.scanCache = .init(
			repeating: .init(),
			count: model.scanClasses.count,
		)
		self.triviaCache = .init(
			repeating: .init(),
			count: model.programs.count,
		)
		self.callCache = .init(
			repeating: .init(),
			count: model.nonterminals.count,
		)
		self.failurePosition = start
	}

	// MARK: タグ環境

	mutating func capture(
		tag: Int32,
		begin: Int32,
		end: Int32,
		in environment: Int32,
	) -> Int32 {
		var values: [Capture]
		= environments[Int(environment)]

		values.removeAll { $0.tag == tag }
		values.append(.init(tag: tag, begin: begin, end: end))
		values.sort { $0.tag < $1.tag }

		if let id: Int32 = environmentIDs[values] {
			return id
		}

		let id: Int32
		= Int32(environments.count)

		environments.append(values)
		environmentIDs[values] = id

		return id
	}

	func captured(
		tag: Int32,
		in environment: Int32,
	) -> Capture? {
		environments[Int(environment)].first { $0.tag == tag }
	}

	// MARK: 診断

	/// 位置が進めば古い期待値を捨てる。期待値の文字列は最後にだけ作る。
	@inline(__always)
	mutating func record(
		_ position: Int32,
		_ expectation: Expectation? = nil,
	) {
		guard
			position >= failurePosition
		else { return }

		if position > failurePosition {
			failurePosition = position
			expectations.removeAll(keepingCapacity: true)
		}

		if let expectation {
			expectations.append(expectation)
		}
	}

	func diagnostic() -> SpelluError {
		var values: Set<Expect> = []

		for expectation: Expectation in expectations {
			switch expectation {
				case let .token(scanClass, start, failed):
					var stream: SourceStream
					= self.stream

					stream.offset = Int(start)

					let position: String.Index
					= source.content.utf8Index(Int(failed))

					values.formUnion(
						model.scanDetails[Int(scanClass)].pattern.expectations(
							in: stream,
							at: position,
						),
					)
				case let .words(scanClass):
					values.formUnion(
						(model.scanDetails[Int(scanClass)].words ?? [])
							.map(Expect.literal),
					)
				case let .value(value):
					values.insert(value)
			}
		}

		let (line, column): (Int, Int)
		= source.position(Int(failurePosition))

		return .unexpected(
			source: source,
			offset: Int(failurePosition),
			line: line,
			column: column,
			expects: Array(values).sorted,
		)
	}

	// MARK: 字句

	/// 字句Triviaの終了位置。同じ位置では全字句で一回だけ照合する。
	mutating func triviaEnd(
		program: Int32,
		at position: Int32,
	) -> Int32 {
		let index: Int
		= Int(program)

		if triviaCache[index].position == position {
			return triviaCache[index].end
		}

		stream.offset = Int(position)

		var end: Int32
		= position

		if case let .success(found) = stream.match(model.programs[index]) {
			end = Int32(stream.offset(of: found))
		}

		triviaCache[index] = .init(position: position, end: end)

		return end
	}

	/// 走査クラスを照合する。同じ位置では一回だけ照合し、結果を共有する。
	mutating func scan(
		_ scanClass: Int32,
		at position: Int32,
	) throws -> ScanEntry {
		let index: Int
		= Int(scanClass)

		if scanCache[index].position == position {
			return scanCache[index]
		}

		try store.budget.spend()

		let info: GrammarModel.ScanClass
		= model.scanClasses[index]

		let begin: Int32
		= info.prefix < 0
			? position
			: triviaEnd(program: info.prefix, at: position)

		stream.offset = Int(begin)

		var entry: ScanEntry
		= .init(position: position, begin: begin)

		switch stream.match(model.programs[Int(info.program)]) {
			case let .failure(found):
				entry.failure = Int32(stream.offset(of: found))

			case let .success(found):
				let end: Int32
				= Int32(stream.offset(of: found))

				if info.hasWords && !accepted(index, begin: begin, end: end) {
					entry.failure = end
				}
				else {
					entry.end = end
				}
		}

		scanCache[index] = entry

		return entry
	}

	private func accepted(
		_ scanClass: Int,
		begin: Int32,
		end: Int32,
	) -> Bool {
		let detail: GrammarModel.ScanDetail
		= model.scanDetails[scanClass]

		let text: String
		= String(source.content[utf8: Int(begin)..<Int(end)])

		guard
			let words: [String] = detail.words
		else { return true }

		return detail.insensitive
			? words.contains { $0.equalsIgnoringCase(text) }
			: words.contains(text)
	}

	/// 失敗の記録は、同じ位置の同じクラスで一回だけ行う。
	mutating func recordScanFailure(
		_ scanClass: Int32,
	) {
		let index: Int
		= Int(scanClass)

		guard
			!scanCache[index].recorded
		else { return }

		scanCache[index].recorded = true

		let entry: ScanEntry
		= scanCache[index]

		record(
			entry.failure,
			model.scanClasses[index].hasWords
				? .words(scanClass)
				: .token(scanClass, entry.begin, entry.failure),
		)
	}

	// MARK: 確定範囲

	mutating func newChartID() -> Int32 {
		defer { chartCount += 1 }

		return chartCount
	}

	@inline(__always)
	static func context(
		position: Int32,
		environment: Int32,
	) -> UInt64 {
		UInt64(UInt32(bitPattern: position)) << 32
			| UInt64(UInt32(bitPattern: environment))
	}

	/// 入口からチャートを進める。子の確定範囲は明示スタックで管理する。
	mutating func parse(
		entry: Int32,
		at start: Int32,
	) throws -> Match {
		var chart: Chart
		= try .init(
			entry: entry,
			position: start,
			environment: 0,
			session: &self,
		)

		var stack: [Chart] = []

		while true {
			switch try chart.run(&self) {
				case let .boundary(id, position, environment):
					try checkReentry(
						id,
						position: position,
						current: chart,
						stack: stack,
					)
					stack.append(chart)
					chart = try .init(
						entry: model.boundaries[Int(id)].entry,
						boundary: id,
						position: position,
						environment: environment,
						session: &self,
					)

				case .finished:
					let resolved: Match?
					= try chart.select(&self)

					guard
						let parent: Chart = stack.popLast()
					else {
						guard
							let resolved
						else { throw diagnostic() }

						return resolved
					}

					storeResult(of: chart, resolved)
					chart = parent
			}
		}
	}

	private mutating func storeResult(
		of chart: Chart,
		_ match: Match?,
	) {
		var index: Int32 = -1

		if let match {
			index = Int32(matches.count)
			matches.append(match)
		}

		// 確定範囲の結果は位置と環境だけで決まるので、後の要求で再利用する。
		// 値の-1は不一致を表すが、表の空きと区別するため1を足して登録する。
		_ = boundaryResults.insert(
			Self.boundaryKey(
				chart.boundary,
				position: chart.start,
				environment: chart.startEnvironment,
			),
			value: index + 1,
		)
	}

	@inline(__always)
	static func boundaryKey(
		_ boundary: Int32,
		position: Int32,
		environment: Int32,
	) -> KeyTable.Key {
		.init(
			high: UInt64(UInt32(bitPattern: boundary)),
			low: context(position: position, environment: environment),
		)
	}

	/// スタック上の同じ境界・同じ開始位置へ戻る呼び出しは循環になる。
	private func checkReentry(
		_ id: Int32,
		position: Int32,
		current: Chart,
		stack: [Chart],
	) throws {
		guard
			stack.count + 1 <= limits.maxBoundaryDepth
		else {
			throw SpelluError.safetyStop(
				.overLimitsOfRecursion(limits: limits.maxBoundaryDepth),
			)
		}

		var found: Bool
		= current.boundary == id && current.start == position

		var index: Int
		= stack.count - 1

		// 子の開始位置は親以降なので、同じ開始位置の範囲だけ調べれば足りる。
		while !found, index >= 0, stack[index].start == position {
			found = stack[index].boundary == id
			index -= 1
		}

		guard
			found
		else { return }

		throw SpelluError.safetyStop(.other("Recursive prefix match"))
	}

	// MARK: 木の具体化

	/// 選ばれた木の列を、明示スタックで `SourceNode` へ変換する。
	mutating func materialize(
		_ roots: Int32,
		strategy: TreeStrategy,
	) throws -> [SourceNode] {
		struct Frame {
			let tree: Int32
			var cursor: [Int32]
			var parts: [SourceNode] = []
		}

		var output: [SourceNode] = []

		for root: Int32 in store.treeLists.values(roots) {
			var stack: [Frame]
			= [
				.init(
					tree: root,
					cursor: [store.trees[Int(root)].children],
				),
			]

			while !stack.isEmpty {
				try store.budget.spend()

				let top: Int
				= stack.count - 1

				if let next: Int32 = store.treeLists.next(&stack[top].cursor) {
					stack.append(
						.init(
							tree: next,
							cursor: [store.trees[Int(next)].children],
						),
					)

					continue
				}

				let frame: Frame
				= stack.removeLast()

				let tree: DerivationStore.Tree
				= store.trees[Int(frame.tree)]

				let grammar: String
				= model.grammars[Int(tree.grammar)].name

				var parts: [SourceNode]
				= frame.parts

				if strategy == .compact {
					parts = []

					var pending: [SourceNode]
					= frame.parts.reversed()

					while let child: SourceNode = pending.popLast() {
						try store.budget.spend()

						if child.grammar == grammar && child.label.isTemporary {
							pending.append(contentsOf: child.parts.reversed())
						}
						else {
							parts.append(child)
						}
					}
				}

				let node: SourceNode
				= .init(
					grammar: grammar,
					label: model.labels[Int(tree.label)],
					source: source,
					begin: Int(tree.begin),
					end: Int(tree.end),
					parts: parts,
				)

				if stack.isEmpty {
					output.append(node)
				}
				else {
					stack[stack.count - 1].parts.append(node)
				}
			}
		}

		return output
	}

}
