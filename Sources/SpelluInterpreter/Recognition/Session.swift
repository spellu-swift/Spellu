import Basis
import SpelluCore
import SpelluLex


/// 確定範囲で選んだ結果。
struct Match {
	let end: Int
	let environment: Environment
	let trees: ListID<TreeID>
	/// 採用した導出で読み飛ばした自動Trivia。入力の順。
	let trivia: ListID<TriviaSpan>
}


///
/// 一回の解析の状態
///
/// 入力、字句の照合、診断、作業量、木のストアの寿命をここに限定する。
///
struct Session {

	/// 照合の結果。
	enum Scan {
		case matched(end: Int)
		case failed(at: Int)

		/// 成功なら終了位置、失敗なら最も遠く読めた位置。
		var position: Int {
			switch self {
				case let .matched(end):
					end
				case let .failed(failure):
					failure
			}
		}
	}

	/// 字句TriviaのProgram。読めるだけ読むものと、一つ以上を確かめるもの。
	struct TriviaPrograms {
		let optional: TokenProgram
		let required: TokenProgram
	}

	/// 子の確定範囲の結果。
	enum BoundaryOutcome {
		case matched(Match)
		case unmatched
	}

	/// 期待値の元。期待値の文字列は、不一致を返すときにだけ作る。
	enum Expectation {
		case token(TokenIR, start: Int, failed: Int)
		case words([String])
		case value(Expect)
	}

	let table: CodeTable
	let source: Source
	let limits: Limits

	/// 木と列のストア。
	var store: Store = .init()

	private var stream: SourceStream
	/// 字句のProgram。添字は字句の番号。まだ作っていなければ `nil`。
	private var programs: [TokenProgram?]
	private var triviaPrograms: [GrammarID: TriviaPrograms] = [:]
	private var work: Int = 0
	private var failurePosition: Int
	private var expectations: [Expectation] = []

	/// 子の確定範囲の結果。結果は子の入口（構文・位置・環境・モード）だけで決まるので使い回す。
	private(set) var boundaryResults: [Call: BoundaryOutcome] = [:]

	init(
		table: CodeTable,
		source: Source,
		limits: Limits,
		start: Int,
	) {
		self.table = table
		self.source = source
		self.limits = limits
		self.stream = .init(
			source,
			engine: .momojiri,
			maxTokenRepetition: limits.maxTokenRepetition,
		)
		self.programs = .init(repeating: nil, count: table.tokens.count)
		self.failurePosition = start
	}

	/// 入口から認識し、出口の候補から一つを選ぶ。
	///
	/// 子の確定範囲は `Evaluation` のスタックで動かす。評価が子の結果を求めて止まったら、
	/// 子の評価を積む。子が終わったら一つを選んで結果を記録し、親の評価を再開する。
	/// Swiftの呼び出しは、確定範囲の入れ子に応じて深くならない。
	mutating func parse(
		_ entry: Construct,
		at start: Int,
	) throws -> Match {
		var current: Evaluation
		= try .init(
			entry: .init(
				construct: entry,
				position: start,
				environment: .init(),
				mode: .init(),
			),
			&self,
		)

		var stack: [Evaluation] = []

		while true {
			switch try current.run(&self) {
				case let .needs(call):
					try checkReentry(call, current: current, stack: stack)

					stack.append(current)
					current = try .init(entry: call, &self)

				case .finished:
					try current.selectAutoTrivia(&self)

					var resolver: Resolver
					= .init(evaluation: current)

					let match: Match?
					= try resolver.select(&self)

					guard
						let parent: Evaluation = stack.popLast()
					else {
						guard
							let match
						else { throw diagnostic() }

						return match
					}

					boundaryResults[current.entry]
					= match.map { .matched($0) } ?? .unmatched

					current = parent
			}
		}
	}

	/// 子の確定範囲を始めてよいか確かめる。
	///
	/// 深さが上限を超えた場合や、処理中の同じ入口・位置・モードに戻った場合は止める。
	private func checkReentry(
		_ call: Call,
		current: Evaluation,
		stack: [Evaluation],
	) throws {
		guard
			stack.count + 1 <= limits.maxBoundaryDepth
		else {
			throw SpelluError.safetyStop(
				.overLimitsOfRecursion(limits: limits.maxBoundaryDepth),
			)
		}

		let active: [Call]
		= ([current] + stack).map(\.entry)

		if active.contains(where: {
			$0.construct == call.construct && $0.position == call.position
				&& $0.mode == call.mode
		}) {
			throw SpelluError.safetyStop(.other("Recursive prefix match"))
		}
	}

}


// MARK: 作業量

extension Session {

	/// 作業量を一つ数える。上限を超えたら止める。
	mutating func spend() throws {
		work += 1

		if work > limits.maxWork {
			throw SpelluError.safetyStop(
				.other("Interpreter work limit exceeded (\(limits.maxWork))"),
			)
		}
	}

}


// MARK: 字句

extension Session {

	/// 字句を照合する。
	mutating func scan(
		_ pattern: TokenIR,
		token: TokenID,
		at position: Int,
	) throws -> Scan {
		try spend()

		stream.offset = position

		switch stream.match(program(for: pattern, token: token)) {
			case let .success(found):
				return .matched(end: stream.offset(of: found))

			case let .failure(found):
				return .failed(at: stream.offset(of: found))
		}
	}

	/// 字句Trivia（空白など）を読めるだけ読み、終了位置を返す。字句Triviaがなければ位置のまま。
	///
	/// 記録するときは、字句Triviaが一つも読めなかった位置に期待値 `.trivia` を残す。
	mutating func scanLexicalTrivia(
		of grammar: GrammarID,
		at position: Int,
		silent: Bool,
	) throws -> Int {
		let patterns: [TokenIR]
		= table[grammar].lexicalTrivia

		guard
			!patterns.isEmpty
		else { return position }

		try spend()

		let programs: TriviaPrograms
		= triviaPrograms[grammar] ?? .init(
			optional: TokenProgramCompiler().compile(
				.alternative(patterns, amount: .zeroOrMore),
			),
			required: TokenProgramCompiler().compile(
				.alternative(patterns, amount: .oneOrMore),
			),
		)

		triviaPrograms[grammar] = programs

		var end: Int
		= position

		stream.offset = position

		if case let .success(found) = stream.match(programs.optional) {
			end = stream.offset(of: found)
		}

		if !silent {
			stream.offset = position

			if case let .failure(found) = stream.match(programs.required) {
				record(stream.offset(of: found), .value(.trivia))
			}
		}

		return end
	}

	/// 後方参照の文字列を照合する。一致すれば終了位置。
	mutating func matchReference(
		_ text: String,
		at position: Int,
	) throws -> Int? {
		try spend()

		stream.offset = position

		return stream.matchReference(text)
	}

	/// 原文の範囲の文字列。
	func text(
		_ range: Range<Int>,
	) -> String {
		String(source.content[utf8: range])
	}

	/// Wordの語の一覧に、読んだ範囲の文字列が入っているか。
	func accepts(
		_ range: Range<Int>,
		words: [String],
		caseInsensitive: Bool,
	) -> Bool {
		let text: String
		= String(source.content[utf8: range])

		return caseInsensitive
			? words.contains { $0.equalsIgnoringCase(text) }
			: words.contains(text)
	}

	/// 字句のProgram。字句の番号ごとに一度だけ作る。
	private mutating func program(
		for pattern: TokenIR,
		token: TokenID,
	) -> TokenProgram {
		if let program: TokenProgram = programs[token.rawValue] {
			return program
		}

		let program: TokenProgram
		= TokenProgramCompiler().compile(pattern)

		programs[token.rawValue] = program

		return program
	}

}


// MARK: 診断

extension Session {

	/// 失敗を記録する。位置が進めば、それまでの期待値を捨てる。
	mutating func record(
		_ position: Int,
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

	/// 最も遠い失敗の位置と期待値から、不一致のエラーを作る。
	func diagnostic() -> SpelluError {
		var values: Set<Expect> = []

		for expectation: Expectation in expectations {
			switch expectation {
				case let .token(pattern, start, failed):
					var stream: SourceStream
					= self.stream

					stream.offset = start

					values.formUnion(
						pattern.expectations(
							in: stream,
							at: source.content.utf8Index(failed),
						),
					)

				case let .words(words):
					values.formUnion(words.map(Expect.literal))

				case let .value(value):
					values.insert(value)
			}
		}

		let (line, column): (Int, Int)
		= source.position(failurePosition)

		return .unexpected(
			source: source,
			offset: failurePosition,
			line: line,
			column: column,
			expects: Array(values).sorted,
		)
	}

}
