import SpelluCore


///
/// 確定範囲ひとつ分の認識（GLL法）
///
/// 道具は3つある。
/// - ディスクリプタ：「どの呼び出しの中で、文法と入力のどこまで読んだか」。
///   SPPFの中間ノードを兼ねる。
/// - GSS：呼び出し（`Call`）と、その戻りを待つディスクリプタ。
/// - SPPF：ディスクリプタと呼び出しの結果に付けた導出。
///
/// ディスクリプタは作業キューから一つずつ取り出して実行する。
/// Swiftの呼び出しは、入力の長さや文法の入れ子に応じて深くならない。
///
/// 子の確定範囲（Atomic・別の文法のルール）の結果がまだなければ、
/// そのディスクリプタを作業キューへ戻して止まり、`needs` で子の入口を伝える。
/// 子の評価は `Session` が動かし、結果を記録してから、この評価を再開する。
///
struct Evaluation {

	/// 評価が止まった理由。
	enum Event {
		/// 作業キューが空になった。
		case finished
		/// 子の確定範囲の結果が要る。値は子の入口の呼び出し。
		case needs(Call)
	}

	struct CallRecord {
		/// 戻りを待つディスクリプタ（GSSの辺）。戻ったら次のスロットへ進む。
		var waiters: [Descriptor] = []
		/// これまでに得た結果（popの記録）。
		var results: [CallResult] = []
	}

	let entry: Call

	/// 呼び出しの表（GSS）。
	private(set) var calls: [Call: CallRecord] = [:]

	/// 作ったディスクリプタと、その導出。一度作ったディスクリプタは二度と実行しない。
	private(set) var derivations: [Descriptor: [Derivation]] = [:]

	/// 呼び出しの結果と、その導出（命令列の終わりに着いたディスクリプタ）。
	private(set) var families: [CallResult: [Descriptor]] = [:]

	/// 本文の導出が参照する自動Triviaの結果と、採用した構文Triviaの範囲の列。
	private(set) var autoTrivia: [CallResult: ListID<TriviaSpan>] = [:]

	/// `autoTrivia` のキーを、最初に参照された順に並べたもの。
	private var skips: [CallResult] = []

	/// 実行を待つディスクリプタ。
	private var worklist: [Descriptor] = []

	/// 実行中の命令が求めた、子の確定範囲の入口。
	private var request: Call? = nil

	/// 入口を呼んだ評価を作る。
	init(
		entry: Call,
		_ session: inout Session,
	) throws {
		self.entry = entry

		try open(entry, &session)
	}

	/// 入口の呼び出しの結果。これが出口の候補になる。
	var exits: [CallResult] {
		calls[entry]?.results ?? []
	}

	/// 作業キューが空になるか、子の確定範囲の結果が要るまでディスクリプタを実行する。
	mutating func run(
		_ session: inout Session,
	) throws -> Event {
		while let descriptor: Descriptor = worklist.popLast() {
			try execute(descriptor, &session)

			if let call: Call = request {
				// 子の結果を記録してから、同じディスクリプタをもう一度実行する。
				request = nil
				worklist.append(descriptor)

				return .needs(call)
			}
		}

		return .finished
	}

	/// 子の確定範囲の結果を求める。結果がまだなければ評価を止める。
	mutating func requestBoundary(
		_ call: Call,
	) {
		request = call
	}

}


// MARK: GLLの基本操作

extension Evaluation {

	/// 構文を呼ぶ。呼び出しが新しければ選択肢を始め、既に結果があれば渡す。
	mutating func call(
		_ construct: Construct,
		from descriptor: Descriptor,
		mode: Mode,
		_ session: inout Session,
	) throws {
		let call: Call
		= .init(
			construct: construct,
			position: descriptor.position,
			environment: descriptor.environment,
			mode: mode,
		)

		if calls[call] == nil {
			try open(call, &session)
		}

		calls[call]!.waiters.append(descriptor)

		// 先に完了した結果（空の選択肢や左再帰）を取りこぼさない。
		let results: [CallResult]
		= calls[call]!.results

		for result: CallResult in results {
			try resume(descriptor, with: result, &session)
		}
	}

	/// 命令列の終わり。呼び出しの結果を作り、待っているディスクリプタへ渡す。
	mutating func complete(
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		// Captureは、本文で記録したtagを外へ持ち出さない。
		var environment: Environment
		= descriptor.environment

		if case .capture = descriptor.call.construct {
			environment = descriptor.call.environment
		}

		let result: CallResult
		= .init(
			call: descriptor.call,
			end: descriptor.position,
			environment: environment,
		)

		try session.spend()

		// 同じ結果に別の導出が増えても、通知はやり直さない。
		// 待ち側は結果を参照しているので、選択のときにすべての導出をたどれる。
		if families[result] != nil {
			families[result]!.append(descriptor)

			return
		}

		families[result] = [descriptor]
		calls[descriptor.call]!.results.append(result)

		let waiters: [Descriptor]
		= calls[descriptor.call]!.waiters

		for waiter: Descriptor in waiters {
			try resume(waiter, with: result, &session)
		}
	}

	/// 呼び出しの結果で、待っていたディスクリプタを次のスロットへ進める。
	/// 反復の一回が空だった場合など、戻り先が結果によって変わることがある。
	mutating func resume(
		_ waiter: Descriptor,
		with result: CallResult,
		_ session: inout Session,
	) throws {
		guard
			let (slot, child): (Slot, Child)
				= try continuation(of: waiter, returning: result, &session)
		else { return }

		try advance(
			waiter,
			into: slot,
			at: result.end,
			environment: result.environment,
			child: child,
			&session,
		)
	}

	/// 命令列の次の命令へ進める。
	mutating func advance(
		_ descriptor: Descriptor,
		to position: Int,
		environment: Environment,
		child: Child,
		_ session: inout Session,
	) throws {
		let location: Location

		switch descriptor.slot {
			case let .code(value), let .afterTrivia(value):
				location = value

			default:
				throw SpelluError.internalError(
					"Only an instruction advances to the next instruction",
				)
		}

		try advance(
			descriptor,
			into: .code(location.next),
			at: position,
			environment: environment,
			child: child,
			&session,
		)
	}

	/// ディスクリプタを指定のスロットへ進める。
	/// 同じディスクリプタが既にあれば、導出だけを足して作業は積まない。
	mutating func advance(
		_ descriptor: Descriptor,
		into slot: Slot,
		at position: Int,
		environment: Environment,
		child: Child,
		_ session: inout Session,
	) throws {
		let next: Descriptor
		= .init(
			slot: slot,
			call: descriptor.call,
			position: position,
			environment: environment,
		)

		let derivation: Derivation
		= .init(left: descriptor, right: child)

		try session.spend()

		if derivations[next] == nil {
			derivations[next] = [derivation]
			worklist.append(next)
		}
		else if !derivations[next]!.contains(derivation) {
			derivations[next]!.append(derivation)
		}
	}

	/// 呼び出しを作り、構文の各選択肢の先頭でディスクリプタを作る。
	private mutating func open(
		_ call: Call,
		_ session: inout Session,
	) throws {
		calls[call] = .init()

		for slot: Slot in session.table.alternatives(of: call.construct) {
			let descriptor: Descriptor
			= .init(
				slot: slot,
				call: call,
				position: call.position,
				environment: call.environment,
			)

			try session.spend()

			if derivations[descriptor] == nil {
				derivations[descriptor] = []
				worklist.append(descriptor)
			}
		}
	}

	/// ディスクリプタのスロットにある命令を実行する。
	private mutating func execute(
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		switch descriptor.slot {
			case let .code(location):
				guard
					let instruction: SyntaxIR
						= session.table.instruction(at: location)
				else {
					try complete(descriptor, &session)

					return
				}

				// 呼び出しやAtomの識別には、複製した命令でも元の場所を使う。
				try execute(
					instruction,
					at: session.table.canonical(location),
					descriptor,
					&session,
				)

			case let .optional(location, step):
				try executeOptional(step, at: location, descriptor, &session)

			case let .loop(location, count):
				try executeLoop(count, at: location, descriptor, &session)

			case .final:
				try complete(descriptor, &session)

			case let .trivia(grammar, step):
				try executeTrivia(step, of: grammar, descriptor, &session)

			case let .whole(rule, step):
				try executeWhole(step, of: rule, descriptor, &session)

			case let .afterTrivia(location):
				guard
					let instruction: SyntaxIR
						= session.table.instruction(at: location)
				else {
					throw SpelluError.internalError(
						"Trivia must precede an instruction",
					)
				}

				try perform(
					instruction,
					at: session.table.canonical(location),
					descriptor,
					&session,
				)
		}
	}

	/// 自動Triviaの結果を導出の子にする。構文Triviaがない文法では範囲が生じない。
	private mutating func skipped(
		_ result: CallResult,
		_ table: CodeTable,
	) -> Child {
		guard
			case let .trivia(grammar) = result.call.construct,
			!table[grammar].syntaxTrivia.isEmpty
		else { return .nothing }

		if autoTrivia.updateValue(.empty, forKey: result) == nil {
			skips.append(result)
		}

		return .autoTrivia(result)
	}

	/// 認識が終わった後で、本文の導出が参照する自動Triviaの読み方を決める。
	mutating func selectAutoTrivia(
		_ session: inout Session,
	) throws {
		var reader: TriviaReader
		= .init(derivations: derivations)

		for result: CallResult in skips {
			guard
				let descriptor: Descriptor = families[result]?.first
			else {
				throw SpelluError.internalError(
					"Automatic trivia result must have a family",
				)
			}

			autoTrivia[result] = try reader.path(to: descriptor, &session)
		}
	}

	/// 呼び出しから戻ったディスクリプタの次のスロットと、導出の右の子。
	/// 戻りを受け付けないときは `nil`。
	///
	/// - 命令の前の自動Triviaから戻ったら、命令の本体へ進む。Triviaは木を作らず、
	///   構文Triviaの範囲だけを子にする（`SourceTree.trivia` に入れる）。
	/// - 明示Triviaは、空でなければ範囲全体を一つの葉にする。空なら失敗を記録する。
	/// - 構文Triviaは、空でなければ次の字句Triviaへ進む。
	/// - 反復の一回は、空だったかどうかで戻り先が変わる。
	private mutating func continuation(
		of waiter: Descriptor,
		returning result: CallResult,
		_ session: inout Session,
	) throws -> (Slot, Child)? {
		let empty: Bool
		= result.end == waiter.position

		switch waiter.slot {
			case let .code(location):
				switch session.table.instruction(at: location) {
					case .trivia?:
						guard
							!empty
						else {
							if !waiter.call.mode.silent {
								session.record(waiter.position, .value(.trivia))
							}

							return nil
						}

						return (
							.code(location.next),
							.explicitTrivia(
								location,
								begin: waiter.position,
								end: result.end,
							),
						)

					case .token?, .word?, .tokenref?:
						return (
							.afterTrivia(location),
							skipped(result, session.table),
						)

					default:
						return (.code(location.next), .result(result))
				}

			case let .optional(location, .body):
				return (.optional(location, .afterBody), .result(result))

			case let .loop(location, count):
				let slot: Slot
				= try loopContinuation(
					count,
					at: location,
					empty: empty,
					session,
				)

				return (slot, .result(result))

			case let .trivia(grammar, .syntax):
				return empty ? nil : (.trivia(grammar, .lexical), .nothing)

			case let .whole(rule, .rule):
				return (.whole(rule, .trivia), .result(result))

			case let .whole(rule, .trivia):
				return (
					.whole(rule, .end),
					skipped(result, session.table),
				)

			case .optional, .final, .trivia, .afterTrivia, .whole:
				throw SpelluError.internalError(
					"This slot does not wait for a call",
				)
		}
	}

}
