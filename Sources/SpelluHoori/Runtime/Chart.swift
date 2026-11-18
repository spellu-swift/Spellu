import SpelluCore
import SpelluLex


/// 一つの確定範囲のEarleyチャート。位置ごとの項目集合を小さい順に処理する。
///
/// - 項目：`(ドット位置, 呼び出し, 環境)`。同じ位置の同じ項目は一つにまとめ、
///   別の導出はリンクとして足す。
/// - 呼び出し：`(非終端, 位置, 環境)`。予測は呼び出しごとに一度だけ行う。
/// - 記号ノード：`(呼び出し, 終了位置, 出力環境)`。別の導出は家族として足す。
struct Chart {

	struct Item {
		let dot: Int32
		let call: Int32
		let environment: Int32
		let position: Int32
		/// 一本目のリンク。初期項目の `left` は-1。
		let left: Int32
		let right: Int32
		/// 二本目以降のリンク。
		var more: Int32 = -1
		/// 同じ位置の集合で次に処理する項目。
		var next: Int32 = -1
	}

	struct Call {
		let nonterminal: Int32
		let position: Int32
		let environment: Int32
		var waiters: Int32 = -1
		var lastNode: Int32 = -1
	}

	struct Node {
		let call: Int32
		let end: Int32
		let environment: Int32
		/// 同じ呼び出しの、一つ前に作られた記号ノード。
		let previous: Int32
		/// 一件目の家族（完了した項目）。
		let family: Int32
		var more: Int32 = -1
	}

	struct Link {
		let left: Int32
		let right: Int32
		let next: Int32
	}

	struct Chain {
		let value: Int32
		let next: Int32
	}

	struct Bucket {
		var head: Int32
		var tail: Int32
	}

	enum Event {
		case boundary(Int32, Int32, Int32)
		case finished
	}

	let id: Int32
	let boundary: Int32
	let start: Int32
	let startEnvironment: Int32

	private(set) var items: [Item] = []
	private(set) var calls: [Call] = []
	private(set) var nodes: [Node] = []
	private(set) var links: [Link] = []
	private(set) var families: [Chain] = []
	private var waiters: [Chain] = []

	private var itemIndex: KeyTable = .init()
	private var callIndex: KeyTable = .init()
	private var buckets: [Bucket] = []
	private var bucketIndex: KeyTable = .init()
	private var pending: [Int32] = []
	private var position: Int32
	private var cursor: Int32 = -1
	private var tail: Int32 = -1

	init(
		entry: Int32,
		boundary: Int32 = -1,
		position: Int32,
		environment: Int32,
		session: inout Session,
	) throws {
		self.id = session.newChartID()
		self.boundary = boundary
		self.start = position
		self.startEnvironment = environment
		self.position = position

		_ = try call(
			entry,
			environment: environment,
			session: &session,
		)
	}

	// MARK: 実行

	/// キューが尽きるか、子の確定範囲が必要になるまで進める。
	mutating func run(
		_ session: inout Session,
	) throws -> Event {
		while true {
			if cursor < 0 {
				guard
					advancePosition()
				else { return .finished }
			}

			let id: Int
			= Int(cursor)

			let item: Item
			= items[id]

			switch session.model.symbols[Int(item.dot)] {
				case let .nonterminal(nonterminal, _):
					try request(
						nonterminal,
						from: cursor,
						session: &session,
					)

				case let .lexeme(lexeme):
					try scan(
						lexeme,
						item: cursor,
						session: &session,
					)

				case let .reference(reference):
					try scanReference(
						reference,
						item: cursor,
						session: &session,
					)

				case let .boundary(boundary):
					let key: KeyTable.Key
					= Session.boundaryKey(
						boundary,
						position: position,
						environment: item.environment,
					)

					guard
						let result: Int32 = session.boundaryResults.find(key)
					else {
						return .boundary(boundary, position, item.environment)
					}

					try resume(
						boundary,
						result: result - 1,
						item: cursor,
						session: &session,
					)

				case let .trivia(site):
					try scanTrivia(
						site,
						item: cursor,
						session: &session,
					)

				case let .eos(silent):
					if position == session.upperBound {
						try advance(
							cursor,
							right: position,
							target: position,
							environment: item.environment,
							session: &session,
						)
					}
					else if !silent {
						session.record(position, .value(.eos))
					}

				case .point:
					try advance(
						cursor,
						right: position,
						target: position,
						environment: item.environment,
						session: &session,
					)

				case let .never(silent):
					if !silent {
						session.record(position, .value(.character("NEVER")))
					}

				case let .end(production):
					try complete(
						cursor,
						production: production,
						session: &session,
					)
			}

			cursor = items[id].next
		}
	}

	/// 次に小さい位置の集合へ移る。
	private mutating func advancePosition() -> Bool {
		guard
			let next: Int32 = popPending()
		else { return false }

		position = next

		let bucket: Bucket
		= buckets[Int(bucketIndex.find(positionKey(next))!)]

		cursor = bucket.head
		tail = bucket.tail

		return true
	}

	// MARK: 予測

	/// 非終端記号を待つ。初めての呼び出しなら生成規則の初期項目を追加する。
	private mutating func request(
		_ nonterminal: Int32,
		from item: Int32,
		session: inout Session,
	) throws {
		let call: Int32
		= try call(
			nonterminal,
			environment: items[Int(item)].environment,
			session: &session,
		)

		waiters.append(.init(value: item, next: calls[Int(call)].waiters))
		calls[Int(call)].waiters = Int32(waiters.count - 1)

		// 同じ位置で既に完了した結果（空規則など）を渡す。
		var node: Int32
		= calls[Int(call)].lastNode

		while node >= 0 {
			try deliver(node, to: item, session: &session)
			node = nodes[Int(node)].previous
		}
	}

	private mutating func call(
		_ nonterminal: Int32,
		environment: Int32,
		session: inout Session,
	) throws -> Int32 {
		let context: UInt64
		= Session.context(position: position, environment: environment)

		let entry: Session.CallEntry
		= session.callCache[Int(nonterminal)]

		if entry.chart == id && entry.context == context {
			return entry.call
		}

		let new: Int32
		= Int32(calls.count)

		let found: Int32?
		= callIndex.insert(
			.init(
				high: UInt64(UInt32(bitPattern: nonterminal)),
				low: context,
			),
			value: new,
		)

		session.callCache[Int(nonterminal)] = .init(
			chart: id,
			context: context,
			call: found ?? new,
		)

		if let found {
			return found
		}

		calls.append(
			.init(
				nonterminal: nonterminal,
				position: position,
				environment: environment,
			),
		)

		let range: Range<Int32>
		= session.model.nonterminals[Int(nonterminal)].productions

		for index: Int32 in range {
			let production: GrammarModel.Production
			= session.model.productions[
				Int(session.model.productionOrder[Int(index)])
			]

			try session.store.budget.spend()

			items.append(
				.init(
					dot: production.first,
					call: new,
					environment: environment,
					position: position,
					left: -1,
					right: -1,
				),
			)
			enqueueCurrent(Int32(items.count - 1))
		}

		return new
	}

	// MARK: 走査

	private mutating func scan(
		_ lexeme: Int32,
		item: Int32,
		session: inout Session,
	) throws {
		let site: GrammarModel.Lexeme
		= session.model.lexemes[Int(lexeme)]

		let result: Session.ScanEntry
		= try session.scan(site.scanClass, at: position)

		guard
			result.end >= 0
		else {
			if !site.silent {
				session.recordScanFailure(site.scanClass)
			}

			return
		}

		var environment: Int32
		= items[Int(item)].environment

		if site.tag >= 0 {
			environment = session.capture(
				tag: site.tag,
				begin: result.begin,
				end: result.end,
				in: environment,
			)
		}

		try advance(
			item,
			right: result.begin,
			target: result.end,
			environment: environment,
			session: &session,
		)
	}

	private mutating func scanReference(
		_ reference: Int32,
		item: Int32,
		session: inout Session,
	) throws {
		let site: GrammarModel.Reference
		= session.model.references[Int(reference)]

		let environment: Int32
		= items[Int(item)].environment

		guard
			let capture: Session.Capture = session.captured(
				tag: site.tag,
				in: environment,
			)
		else {
			if !site.silent {
				session.record(position)
			}

			return
		}

		let text: String
		= String(
			session.source.content[
				utf8: Int(capture.begin)..<Int(capture.end)
			],
		)

		session.stream.offset = Int(position)

		guard
			let end: Int = session.stream.matchReference(text)
		else {
			if !site.silent {
				session.record(position, .value(.literal(text)))
			}

			return
		}

		try advance(
			item,
			right: position,
			target: Int32(end),
			environment: environment,
			session: &session,
		)
	}

	private mutating func scanTrivia(
		_ site: Int32,
		item: Int32,
		session: inout Session,
	) throws {
		let plan: GrammarModel.TriviaScan
		= session.model.triviaScans[Int(site)]

		let end: Int32
		= session.triviaEnd(program: plan.optional, at: position)

		if !plan.silent {
			session.stream.offset = Int(position)

			let required: TokenProgram
			= session.model.programs[Int(plan.required)]

			if case let .failure(found) = session.stream.match(required) {
				session.record(
					Int32(session.stream.offset(of: found)),
					.value(.trivia),
				)
			}
		}

		try advance(
			item,
			right: position,
			target: end,
			environment: items[Int(item)].environment,
			session: &session,
		)
	}

	/// 子の確定範囲の結果で項目を進める。親は子の別候補を選び直せない。
	private mutating func resume(
		_ boundary: Int32,
		result: Int32,
		item: Int32,
		session: inout Session,
	) throws {
		guard
			result >= 0
		else { return }

		let match: Match
		= session.matches[Int(result)]

		if session.model.boundaries[Int(boundary)].probe {
			try advance(
				item,
				right: result,
				target: position,
				environment: items[Int(item)].environment,
				session: &session,
			)
		}
		else {
			try advance(
				item,
				right: result,
				target: match.end,
				environment: match.environment,
				session: &session,
			)
		}
	}

	// MARK: 完了

	private mutating func complete(
		_ item: Int32,
		production: Int32,
		session: inout Session,
	) throws {
		let callID: Int32
		= items[Int(item)].call

		let call: Call
		= calls[Int(callID)]

		var environment: Int32
		= items[Int(item)].environment

		if case .capture = session.model.nonterminals[Int(call.nonterminal)].kind {
			environment = call.environment
		}

		// 新しい順に並ぶので、現在の位置の結果だけを調べれば足りる。
		var node: Int32
		= call.lastNode

		while node >= 0, nodes[Int(node)].end == position {
			if nodes[Int(node)].environment == environment {
				try session.store.budget.spend()

				families.append(
					.init(value: item, next: nodes[Int(node)].more),
				)
				nodes[Int(node)].more = Int32(families.count - 1)

				return
			}

			node = nodes[Int(node)].previous
		}

		try session.store.budget.spend()

		nodes.append(
			.init(
				call: callID,
				end: position,
				environment: environment,
				previous: call.lastNode,
				family: item,
			),
		)

		let new: Int32
		= Int32(nodes.count - 1)

		calls[Int(callID)].lastNode = new

		var waiter: Int32
		= call.waiters

		while waiter >= 0 {
			try deliver(
				new,
				to: waiters[Int(waiter)].value,
				session: &session,
			)
			waiter = waiters[Int(waiter)].next
		}
	}

	/// 記号ノードを待ち項目へ渡す。
	private mutating func deliver(
		_ node: Int32,
		to waiter: Int32,
		session: inout Session,
	) throws {
		let source: Item
		= items[Int(waiter)]

		let target: Node
		= nodes[Int(node)]

		guard
			case let .nonterminal(_, condition)
				= session.model.symbols[Int(source.dot)]
		else { preconditionFailure() }

		switch condition {
			case .none:
				break

			case .nonEmpty:
				if target.end == source.position {
					return
				}

			case .emptyOnly:
				if target.end != source.position {
					return
				}

			case let .required(count):
				if target.end == source.position,
					count > session.limits.maxEmptyRepetition
				{
					throw SpelluError.safetyStop(
						.overLimitsOfRepetition(
							limits: session.limits.maxEmptyRepetition,
						),
					)
				}

			case let .explicitTrivia(silent):
				if target.end == source.position {
					if !silent {
						session.record(target.end, .value(.trivia))
					}

					return
				}
		}

		try advance(
			waiter,
			right: node,
			target: target.end,
			environment: target.environment,
			session: &session,
		)
	}

	/// 項目のドットを一つ進める。同じ項目があれば別の導出としてリンクを足す。
	private mutating func advance(
		_ item: Int32,
		right: Int32,
		target: Int32,
		environment: Int32,
		session: inout Session,
	) throws {
		let source: Item
		= items[Int(item)]

		let dot: Int32
		= source.dot + 1

		let new: Int32
		= Int32(items.count)

		let key: KeyTable.Key
		= .init(
			high: UInt64(UInt32(bitPattern: target)) << 32
				| UInt64(UInt32(bitPattern: dot)),
			low: UInt64(UInt32(bitPattern: source.call)) << 32
				| UInt64(UInt32(bitPattern: environment)),
		)

		try session.store.budget.spend()

		if let existing: Int32 = itemIndex.insert(key, value: new) {
			links.append(
				.init(
					left: item,
					right: right,
					next: items[Int(existing)].more,
				),
			)
			items[Int(existing)].more = Int32(links.count - 1)

			return
		}

		items.append(
			.init(
				dot: dot,
				call: source.call,
				environment: environment,
				position: target,
				left: item,
				right: right,
			),
		)

		if target == position {
			enqueueCurrent(new)
		}
		else {
			enqueue(new, at: target)
		}
	}

	// MARK: 位置ごとの集合

	@inline(__always)
	private mutating func enqueueCurrent(
		_ item: Int32,
	) {
		if tail < 0 {
			cursor = item
		}
		else {
			items[Int(tail)].next = item
		}

		tail = item
	}

	@inline(__always)
	private func positionKey(
		_ value: Int32,
	) -> KeyTable.Key {
		.init(high: UInt64(UInt32(bitPattern: value)), low: 0)
	}

	private mutating func enqueue(
		_ item: Int32,
		at target: Int32,
	) {
		let new: Int32
		= Int32(buckets.count)

		if let bucket: Int32 = bucketIndex.insert(
			positionKey(target),
			value: new,
		) {
			items[Int(buckets[Int(bucket)].tail)].next = item
			buckets[Int(bucket)].tail = item

			return
		}

		buckets.append(.init(head: item, tail: item))
		pushPending(target)
	}

	/// 未処理の位置の最小ヒープ。
	private mutating func pushPending(
		_ value: Int32,
	) {
		pending.append(value)

		var child: Int
		= pending.count - 1

		while child > 0 {
			let parent: Int
			= (child - 1) / 2

			if pending[parent] <= pending[child] {
				break
			}

			pending.swapAt(parent, child)
			child = parent
		}
	}

	private mutating func popPending() -> Int32? {
		guard
			let first: Int32 = pending.first
		else { return nil }

		let last: Int32
		= pending.removeLast()

		if !pending.isEmpty {
			pending[0] = last

			var parent: Int = 0

			while true {
				var smallest: Int
				= parent

				for child: Int in [parent * 2 + 1, parent * 2 + 2]
				where child < pending.count
					&& pending[child] < pending[smallest]
				{
					smallest = child
				}

				if smallest == parent {
					break
				}

				pending.swapAt(parent, smallest)
				parent = smallest
			}
		}

		return first
	}

}
