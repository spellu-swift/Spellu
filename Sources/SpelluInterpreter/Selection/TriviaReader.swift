/// 自動Triviaの読み方を一つに決める。
///
/// 読み方が複数あるときは、先頭から順に各構文Triviaが最も長くなるものを採る。
/// 認識が終わってから同じ到達の読み方をすべて比べるので、処理順には依存しない。
struct TriviaReader {

	/// 読み方の、最後の構文Trivia。
	private struct Reading {
		/// 一つ前の読み飛ばしの到達。構文Triviaを読まない導出なら `nil`。
		var parent: Descriptor?
		/// 読んだ構文Triviaの個数。
		var depth: Int = 0
		var begin: Int = -1
		var end: Int = -1
		/// 先頭からここまでの範囲の列。
		var path: ListID<TriviaSpan> = .empty
	}

	private let derivations: [Descriptor: [Derivation]]

	private var readings: [Descriptor: Reading] = [:]

	init(
		derivations: [Descriptor: [Derivation]],
	) {
		self.derivations = derivations
	}

	/// 自動Triviaの終わりの到達に対し、採用した読み方の範囲の列を返す。
	mutating func path(
		to root: Descriptor,
		_ session: inout Session,
	) throws -> ListID<TriviaSpan> {
		var pending: [Descriptor] = [root]

		while let descriptor: Descriptor = pending.last {
			try session.spend()

			if readings[descriptor] != nil {
				pending.removeLast()
			}
			else {
				try resolve(descriptor, &pending, &session)
			}
		}

		return readings[root]!.path
	}

	/// 一つの到達の読み方を決める。前の到達が未解決なら `pending` に積んで戻る。
	private mutating func resolve(
		_ descriptor: Descriptor,
		_ pending: inout [Descriptor],
		_ session: inout Session,
	) throws {
		var best: Reading?
		var waiting: Bool = false

		for var candidate: Reading in candidates(of: descriptor) {
			try session.spend()

			if let parent: Descriptor = candidate.parent {
				guard
					let previous: Reading = readings[parent]
				else {
					pending.append(parent)
					waiting = true

					continue
				}

				candidate.depth = previous.depth + 1
			}

			guard
				!waiting
			else { continue }

			if let current: Reading = best {
				if try isLonger(candidate, than: current, &session) {
					best = candidate
				}
			}
			else {
				best = candidate
			}
		}

		guard
			!waiting,
			var reading: Reading = best
		else { return }

		if let parent: Descriptor = reading.parent,
			let previous: Reading = readings[parent],
			case let .trivia(grammar) = descriptor.call.construct
		{
			reading.path = session.store.triviaLists.appending(
				.init(
					grammar: grammar,
					begin: reading.begin,
					end: reading.end,
					continuing: previous.depth > 0,
				),
				to: previous.path,
			)
		}

		readings[descriptor] = reading
	}

	/// 到達に至る読み方を列挙する。構文Triviaを読まない導出は親のない一件になる。
	private func candidates(
		of descriptor: Descriptor,
	) -> [Reading] {
		var output: [Reading] = []

		for arrival: Derivation in derivations[descriptor] ?? [] {
			let lexical: Descriptor
			= arrival.left

			let previous: [Derivation]
			= derivations[lexical] ?? []

			if previous.isEmpty {
				output.append(.init())
			}

			for derivation: Derivation in previous {
				output.append(
					.init(
						parent: derivation.left,
						begin: derivation.left.position,
						end: lexical.position,
					),
				)
			}
		}

		return output
	}

	/// 先頭から比べて、最初に異なる構文Triviaが長ければ `true`。
	///
	/// 同じ到達の読み方どうしなので、片方がもう片方の先頭部分になることはない。
	private func isLonger(
		_ candidate: Reading,
		than other: Reading,
		_ session: inout Session,
	) throws -> Bool {
		var left: Reading = candidate
		var right: Reading = other

		while left.depth > right.depth {
			try session.spend()
			left = readings[left.parent!]!
		}

		while right.depth > left.depth {
			try session.spend()
			right = readings[right.parent!]!
		}

		while left.parent != right.parent {
			try session.spend()
			left = readings[left.parent!]!
			right = readings[right.parent!]!
		}

		return left.end > right.end
	}

}
