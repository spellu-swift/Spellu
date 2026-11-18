import SpelluCore
import SpelluLex


///
/// 導出から候補を作り、出口で一つを選ぶ
///
/// 導出のたどり方は `Walk` に任せ、ここには「子の候補から自分の候補を作る規則」だけを書く。
/// 規則はHooriの選択と同じ。
///
struct Resolver {

	/// たどる対象。SPPFの記号ノードと中間ノード。
	enum Target : Hashable {
		case result(CallResult)
		case descriptor(Descriptor)
	}

	/// たどるノード。対象と、それを囲むルール呼び出し（循環を打ち切る文脈）の組。
	///
	/// ルールの結果は自身の呼び出しを文脈にし、それ以外は外側の文脈を引き継ぐ。
	/// 同じルール呼び出しの中で同じノードへ戻ったときだけ、循環として打ち切る。
	struct Node : Hashable {
		let target: Target
		let context: Call?
	}

	let evaluation: Evaluation

	private var walk: Walk<Node, [Candidate]> = .init()

	init(
		evaluation: Evaluation,
	) {
		self.evaluation = evaluation
	}

	/// 出口の候補から一つを選ぶ。候補がなければ `nil`。
	///
	/// 劣る候補を捨て、同値や比較不能な候補が残れば曖昧性にする。
	mutating func select(
		_ session: inout Session,
	) throws -> Match? {
		var frontier: [(candidate: Candidate, exit: CallResult)] = []

		for exit: CallResult in evaluation.exits {
			for candidate: Candidate in try candidates(of: exit, &session) {
				try session.spend()

				if Self.prevails(candidate, over: &frontier, session.store) {
					frontier.append((candidate, exit))
				}
			}
		}

		guard
			let winner: (candidate: Candidate, exit: CallResult)
				= frontier.first
		else { return nil }

		guard
			frontier.count == 1
		else {
			throw SpelluError.ambiguousPath(
				precedence: Self.priority(winner.candidate, session.store),
			)
		}

		return .init(
			end: winner.exit.end,
			environment: winner.exit.environment,
			trees: winner.candidate.trees,
			trivia: winner.candidate.trivia,
		)
	}

	/// 呼び出しの結果の候補。
	private mutating func candidates(
		of result: CallResult,
		_ session: inout Session,
	) throws -> [Candidate] {
		let evaluation: Evaluation
		= self.evaluation

		return try walk.value(
			of: .init(
				target: .result(result),
				context: Self.context(of: result, outside: nil),
			),
			children: { node in
				Self.children(of: node, in: evaluation)
			},
			combine: { node, inputs in
				try Self.combine(node, inputs, in: evaluation, &session)
			},
			cut: { _ in
				[]
			},
			tracksCycle: { node in
				// 循環はかならず結果を通るので、結果でだけ調べる（Hooriと同じ）。
				// ディスクリプタでも調べると、別の結果を経由して同じディスクリプタへ
				// 戻ったときに、Hooriより手前で打ち切ってしまう。
				if case .result = node.target {
					return true
				}

				return false
			},
		)
	}

	/// 出口で比べる候補を加えてよいか。劣る既存の候補は取り除く。
	private static func prevails(
		_ candidate: Candidate,
		over frontier: inout [(candidate: Candidate, exit: CallResult)],
		_ store: Store,
	) -> Bool {
		var kept: [(candidate: Candidate, exit: CallResult)] = []

		for existing in frontier {
			let order: Ordering
			= store.compare(
				candidate.selections,
				existing.candidate.selections,
			)

			switch order {
				case .worse:
					return false

				case .better:
					break

				case .same, .unordered:
					kept.append(existing)
			}
		}

		frontier = kept

		return true
	}

	/// 曖昧性のエラーに載せる順位。最上位の選択履歴の順位。
	private static func priority(
		_ candidate: Candidate,
		_ store: Store,
	) -> Int {
		store.selectionLists.first(candidate.selections).map {
			store[$0].rank
		} ?? 0
	}

}


// MARK: たどる子

extension Resolver {

	/// ルールの結果は自身の呼び出し、それ以外は外側の文脈。
	private static func context(
		of result: CallResult,
		outside: Call?,
	) -> Call? {
		if case .rule = result.call.construct {
			return result.call
		}

		return outside
	}

	/// ノードの子。`combine` は同じ順で子の候補を受け取る。
	///
	/// - 結果：各導出（命令列の終わりのディスクリプタ）。
	/// - ディスクリプタ：導出ごとに、左のディスクリプタと、右が呼び出しの結果ならその結果。
	private static func children(
		of node: Node,
		in evaluation: Evaluation,
	) -> [Node] {
		switch node.target {
			case let .result(result):
				return evaluation.families[result]!.map {
					.init(target: .descriptor($0), context: node.context)
				}

			case let .descriptor(descriptor):
				var output: [Node] = []

				for derivation: Derivation
					in evaluation.derivations[descriptor]!
				{
					output.append(
						.init(
							target: .descriptor(derivation.left),
							context: node.context,
						),
					)

					if case let .result(result) = derivation.right {
						output.append(
							.init(
								target: .result(result),
								context: context(
									of: result,
									outside: node.context,
								),
							),
						)
					}
				}

				return output
		}
	}

}


// MARK: 候補を作る規則

extension Resolver {

	/// 変換した結果の候補。比較範囲を閉じたものは、劣る候補との比べ合いに入る。
	private enum Transformed {
		case closed(Candidate)
		case passed(Candidate)
	}

	private static func combine(
		_ node: Node,
		_ inputs: [[Candidate]],
		in evaluation: Evaluation,
		_ session: inout Session,
	) throws -> [Candidate] {
		// 候補が空でも、ノードを一つ組み立てるたびに作業量を数える。
		// 循環を含む値は覚えないので、同じ部分木を何度もたどることがある。
		try session.spend()

		switch node.target {
			case let .result(result):
				return try complete(
					result,
					families: evaluation.families[result]!,
					inputs,
					&session,
				)

			case let .descriptor(descriptor):
				return try join(
					descriptor,
					evaluation.derivations[descriptor]!,
					inputs,
					in: evaluation,
					&session,
				)
		}
	}

	/// 呼び出しの結果の候補。導出ごとに構文の種類に従って変換し、まとめる。
	///
	/// 比較範囲を閉じた候補は、同じ結果の候補のうち厳密に劣るものを捨てる。
	private static func complete(
		_ result: CallResult,
		families: [Descriptor],
		_ inputs: [[Candidate]],
		_ session: inout Session,
	) throws -> [Candidate] {
		var output: [Candidate] = []

		for (family, values) in zip(families, inputs) {
			for value: Candidate in values {
				try session.spend()

				switch try transform(value, of: result, family, &session) {
					case let .closed(candidate):
						compete(candidate, into: &output, session.store)

					case let .passed(candidate):
						collect(candidate, into: &output)
				}
			}
		}

		return output
	}

	/// 結果の候補を、構文の種類に従って変換する。`family` は導出の終わりのディスクリプタ。
	///
	/// - 比較範囲を閉じる：ルール、Sequence、Optional、Optionalの本文、反復の一回、List、
	///   Repeat、Atomicの本文。ルール・Sequence・Atomicの本文は、木を一つのノードに包む。
	/// - 透過：選択肢（枝の順位を足す）、Enclosure、Capture、Relabel（木のラベルを
	///   付け替える）、全体一致の入口。
	private static func transform(
		_ value: Candidate,
		of result: CallResult,
		_ family: Descriptor,
		_ session: inout Session,
	) throws -> Transformed {
		let table: CodeTable
		= session.table

		switch result.call.construct {
			case let .rule(rule):
				let closed: Candidate
				= close(value, in: .rule(rule), &session.store)

				return .closed(
					wrap(
						closed,
						grammar: table[rule].grammar,
						label: table[rule].label,
						end: result.end,
						&session.store,
					),
				)

			case let .sequence(location):
				guard
					case let .sequence(label, _)
						= table.instruction(at: location)
				else {
					throw SpelluError.internalError(
						"Sequence call must point to a sequence",
					)
				}

				let closed: Candidate
				= close(value, in: .sequence(location), &session.store)

				return .closed(
					wrap(
						closed,
						grammar: table.grammar(of: location),
						label: label.ensure("#and"),
						end: result.end,
						&session.store,
					),
				)

			case let .optional(location):
				// 本文ありの選択肢は順位1、本文なしは順位0。
				var ranked: Candidate
				= value

				if case .optional(_, .afterBody) = family.slot {
					ranked.rank += 1
				}

				return .closed(
					close(ranked, in: .optional(location), &session.store),
				)

			case let .optionalBody(location):
				return .closed(
					close(value, in: .optionalBody(location), &session.store),
				)

			case let .iteration(location):
				return .closed(
					close(value, in: .iteration(location), &session.store),
				)

			case let .list(location):
				return .closed(
					close(value, in: .list(location), &session.store),
				)

			case let .atomicBody(location):
				let closed: Candidate
				= close(value, in: .atomic(location), &session.store)

				return .closed(
					wrap(
						closed,
						grammar: table.grammar(of: location),
						label: "#atomic",
						end: result.end,
						&session.store,
					),
				)

			case let .repeat(location):
				let ending: Candidate
				= try ending(of: family, at: location, &session)

				let finished: Candidate
				= try finish(value.iterations, ending: ending, &session)

				return .closed(
					close(finished, in: .loop(location), &session.store),
				)

			case let .choice(location):
				var ranked: Candidate
				= value

				ranked.rank += try rank(of: family, in: location, table)

				return .passed(ranked)

			case let .relabel(location):
				guard
					case let .relabel(label, _)
						= table.instruction(at: location)
				else {
					throw SpelluError.internalError(
						"Relabel call must point to a relabel",
					)
				}

				var relabeled: Candidate
				= value

				relabeled.trees = session.store.relabeled(
					value.trees,
					label: Label(label),
				)

				return .passed(relabeled)

			case .enclosure, .capture, .whole:
				return .passed(value)

			case .trivia, .syntaxTrivia:
				// Triviaの結果は木と順位を使わないので、導出の子にしない（`continuation`）。
				throw SpelluError.internalError(
					"Trivia results are not resolved",
				)
		}
	}

	/// ディスクリプタの候補。導出ごとに「左の候補 × 右の候補」をつなぐ。
	/// 導出のないディスクリプタ（選択肢の先頭）は、何も読んでいない候補を一つ持つ。
	///
	/// 反復の位置では、つなぐ代わりに本文の一回を履歴に積む。反復の位置
	/// （`loop`）では、同じ位置の候補のうち厳密に劣るものを捨てる。
	private static func join(
		_ descriptor: Descriptor,
		_ derivations: [Derivation],
		_ inputs: [[Candidate]],
		in evaluation: Evaluation,
		_ session: inout Session,
	) throws -> [Candidate] {
		guard
			!derivations.isEmpty
		else { return [.empty] }

		var output: [Candidate] = []
		var cursor: Int = 0

		for derivation: Derivation in derivations {
			let lefts: [Candidate]
			= inputs[cursor]

			cursor += 1

			let rights: [Candidate]

			if case .result = derivation.right {
				rights = inputs[cursor]
				cursor += 1
			}
			else {
				rights = [try leaf(derivation.right, in: evaluation, &session)]
			}

			for left: Candidate in lefts {
				for right: Candidate in rights {
					try session.spend()

					switch descriptor.slot {
						case .loop:
							let candidate: Candidate
							= try iterate(
								left,
								right,
								after: derivation.left,
								&session,
							)

							competeHistories(
								candidate,
								into: &output,
								session.store,
							)

						case .final:
							let candidate: Candidate
							= try iterate(
								left,
								right,
								after: derivation.left,
								&session,
							)

							collect(candidate, into: &output)

						case .code, .optional, .trivia, .afterTrivia, .whole:
							collect(
								joined(left, right, &session.store),
								into: &output,
							)
					}
				}
			}
		}

		return output
	}

	/// 本文の一回を履歴に積んだ候補。
	/// 「続けるか終えるか」の比較範囲と順位は、一回前の位置の回数で決まる。
	/// 必須回数未満とreluctantの継続は順位0、eagerの継続は順位1。
	private static func iterate(
		_ head: Candidate,
		_ body: Candidate,
		after previous: Descriptor,
		_ session: inout Session,
	) throws -> Candidate {
		guard
			case let .loop(location, count) = previous.slot
		else {
			throw SpelluError.internalError(
				"An iteration must start at a loop slot",
			)
		}

		let (amount, behavior): (Amount, SyntaxRepetitionBehavior)
		= try session.table.repetition(at: location)

		let iteration: IterationID
		= session.store.iteration(
			.init(
				previous: head.iterations,
				depth: head.iterations.map { session.store[$0].depth + 1 } ?? 1,
				control: .loopControl(location, count: count),
				rank: count < amount.min || behavior == .reluctant ? 0 : 1,
				body: body,
			),
		)

		return .init(trees: .empty, iterations: iteration)
	}

	/// 反復を終えた選択の候補。
	///
	/// 反復の位置で終えた（stop）なら「終える」を選んだ選択履歴を持つ。
	/// 順位はeagerが0、reluctantが1。上限で終えたときと、空の回で終えたとき（final）は
	/// 何も持たない。
	private static func ending(
		of family: Descriptor,
		at location: Location,
		_ session: inout Session,
	) throws -> Candidate {
		guard
			case let .loop(_, count) = family.slot
		else { return .empty }

		let (amount, behavior): (Amount, SyntaxRepetitionBehavior)
		= try session.table.repetition(at: location)

		if count == amount.max {
			return .empty
		}

		return close(
			.empty,
			in: .loopControl(location, count: count),
			rank: behavior == .eager ? 0 : 1,
			&session.store,
		)
	}

	/// 反復の各回を、最初の回からの入れ子の選択履歴にまとめる。
	/// 各回は「本文＋残りの回」を、その回の「続けるか終えるか」の比較範囲で閉じる。
	///
	/// 選択履歴は最後の回から入れ子にする。木と自動Triviaは列の前へつなぐと回数の
	/// 2乗の費用になるので、別に最初の回から順に並べる。
	private static func finish(
		_ history: IterationID?,
		ending: Candidate,
		_ session: inout Session,
	) throws -> Candidate {
		let items: [Iteration]
		= session.store.chain(history).map { session.store[$0] }

		var trees: ListID<TreeID>
		= .empty

		var trivia: ListID<TriviaSpan>
		= .empty

		for item: Iteration in items {
			trees = session.store.treeLists.concat(trees, item.body.trees)
			trivia = session.store.triviaLists.concat(trivia, item.body.trivia)
		}

		trees = session.store.treeLists.concat(trees, ending.trees)
		trivia = session.store.triviaLists.concat(trivia, ending.trivia)

		var result: Candidate
		= ending

		result.trees = .empty
		result.trivia = .empty

		for item: Iteration in items.reversed() {
			try session.spend()

			var body: Candidate
			= item.body

			body.trees = .empty
			body.trivia = .empty

			result = close(
				joined(body, result, &session.store),
				in: item.control,
				rank: item.rank,
				&session.store,
			)
		}

		result.trees = trees
		result.trivia = trivia

		return result
	}

	/// 選択肢の枝の順位。ChoiceOfは後ろから0, 1, 2…、AnyOfは指定の優先値。
	private static func rank(
		of family: Descriptor,
		in choice: Location,
		_ table: CodeTable,
	) throws -> Int {
		guard
			case let .code(end) = family.slot,
			let index: Int = table.children[choice]?.firstIndex(of: end.block)
		else {
			throw SpelluError.internalError(
				"Choice result must end in one of its branches",
			)
		}

		switch table.instruction(at: choice) {
			case let .choiceOf(branches)?:
				return branches.count - index - 1

			case let .anyOf(branches)?:
				return branches[index].precedence.rawValue

			default:
				throw SpelluError.internalError(
					"Choice call must point to a choice",
				)
		}
	}

}


// MARK: 候補の操作

extension Resolver {

	/// 呼び出し以外の右の子の候補。
	private static func leaf(
		_ child: Child,
		in evaluation: Evaluation,
		_ session: inout Session,
	) throws -> Candidate {
		switch child {
			case let .token(location, begin, end):
				let label: Label
				let atom: Atom

				switch session.table.instruction(at: location) {
					case let .token(value, pattern, spacious, _)?:
						label = value
						atom = value == .none
							? .pattern(
								.init(pattern),
								spacious: spacious,
								words: nil,
								caseInsensitive: false,
							)
							: .place(location)

					case let .word(value, pattern, words, insensitive)?:
						label = value
						atom = value == .none
							? .pattern(
								.init(pattern),
								spacious: true,
								words: Array(Set(words)).sorted(),
								caseInsensitive: insensitive,
							)
							: .place(location)

					case let .tokenref(tag, spacious)?:
						label = .none
						atom = .reference(
							session.table.grammar(of: location),
							tag: tag,
							spacious: spacious,
						)

					default:
						throw SpelluError.internalError(
							"Token child must point to a token",
						)
				}

				let tree: TreeID
				= session.store.leaf(
					grammar: session.table.grammar(of: location),
					label: label,
					begin: begin,
					end: end,
				)

				return leaf(tree, atom: atom, &session.store)

			case let .explicitTrivia(location, begin, end):
				let tree: TreeID
				= session.store.leaf(
					grammar: session.table.grammar(of: location),
					label: "#spaces",
					begin: begin,
					end: end,
				)

				return leaf(tree, atom: .trivia, &session.store)

			case let .boundary(location, trees, trivia):
				// 子で確定した木。範囲を持たない子として扱い、子の選択履歴は持ち込まない。
				return .init(
					trees: trees,
					atoms: session.store.atomLists.single(.atomic(location)),
					selections: session.store.leafSelections,
					trivia: trivia,
				)

			case let .autoTrivia(result):
				// 木も比較の材料も作らず、読み飛ばした範囲だけを運ぶ。
				return .init(
					trees: .empty,
					trivia: evaluation.autoTrivia[result]!,
				)

			case .nothing:
				return .empty

			case .result:
				throw SpelluError.internalError(
					"Call results are resolved by the walk",
				)
		}
	}

	/// 葉の候補。範囲を持たない子の選択履歴を一つ持つ。
	private static func leaf(
		_ tree: TreeID,
		atom: Atom,
		_ store: inout Store,
	) -> Candidate {
		.init(
			trees: store.treeLists.single(tree),
			atoms: store.atomLists.single(atom),
			selections: store.leafSelections,
		)
	}

	/// 2つの候補をつなぐ。順位は足し、木と自動Triviaは入力の順に並べる。
	private static func joined(
		_ left: Candidate,
		_ right: Candidate,
		_ store: inout Store,
	) -> Candidate {
		.init(
			trees: store.treeLists.concat(left.trees, right.trees),
			atoms: store.atomLists.concat(left.atoms, right.atoms),
			selections: store.selectionLists.concat(
				left.selections,
				right.selections,
			),
			rank: left.rank + right.rank,
			trivia: store.triviaLists.concat(left.trivia, right.trivia),
		)
	}

	/// 比較範囲を閉じる。内側のAtomと順位は選択履歴へ移り、
	/// 外からは範囲の識別だけが見える。木と自動Triviaはそのまま渡す。
	/// `rank` を指定すると、候補の順位の代わりに使う。
	private static func close(
		_ value: Candidate,
		in scope: Scope,
		rank: Int? = nil,
		_ store: inout Store,
	) -> Candidate {
		let selection: SelectionID
		= store.selection(
			.init(
				scope: scope,
				atoms: value.atoms,
				rank: rank ?? value.rank,
				children: value.selections,
			),
		)

		return .init(
			trees: value.trees,
			atoms: store.atomLists.single(.scope(scope)),
			selections: store.selectionLists.single(selection),
			trivia: value.trivia,
		)
	}

	/// 候補の木を一つの枝に包む。
	private static func wrap(
		_ value: Candidate,
		grammar: GrammarID,
		label: Label,
		end: Int,
		_ store: inout Store,
	) -> Candidate {
		var output: Candidate
		= value

		output.trees = store.treeLists.single(
			store.branch(
				grammar: grammar,
				label: label,
				children: value.trees,
				cursor: end,
			),
		)

		return output
	}

	/// 同じ候補がまだなければ加える。
	private static func collect(
		_ candidate: Candidate,
		into output: inout [Candidate],
	) {
		if !output.contains(candidate) {
			output.append(candidate)
		}
	}

	/// 比較範囲を閉じた候補を加える。同じ結果の候補のうち、厳密に劣るものを捨てる。
	///
	/// 閉じた候補の後続は結果だけで決まり、比較は最初の差で決まる。
	/// そのため、劣る候補を使う導出は、優る候補に置き換えた導出に必ず負ける。
	/// 同値と比較不能な候補は、外側の比較で決まる場合があるので残す。
	private static func compete(
		_ candidate: Candidate,
		into output: inout [Candidate],
		_ store: Store,
	) {
		var kept: [Candidate] = []

		for existing: Candidate in output {
			switch store.compare(candidate.selections, existing.selections) {
				case .worse:
					return

				case .same:
					if candidate == existing {
						return
					}

					kept.append(existing)

				case .unordered:
					kept.append(existing)

				case .better:
					break
			}
		}

		kept.append(candidate)
		output = kept
	}

	/// 反復の位置の候補を加える。同じ位置の候補のうち、厳密に劣るものと同値のものを捨てる。
	///
	/// 同じ位置からの後続は同じなので、最初の回から比べて劣る履歴は、優る履歴に
	/// 置き換えた導出に必ず負ける。
	private static func competeHistories(
		_ candidate: Candidate,
		into output: inout [Candidate],
		_ store: Store,
	) {
		var kept: [Candidate] = []

		for existing: Candidate in output {
			let order: Ordering
			= store.compareHistories(
				candidate.iterations,
				existing.iterations,
			)

			switch order {
				case .worse, .same:
					return

				case .unordered:
					kept.append(existing)

				case .better:
					break
			}
		}

		kept.append(candidate)
		output = kept
	}

}
