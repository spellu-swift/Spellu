///
/// 選択の候補
///
/// 値は番号だけなので、等しいかどうかは番号の比較で分かる。
/// 規則はHooriの選択と同じ。
///
/// 自動Triviaの列は、採用した導出のものを運ぶだけで、順位の比較には使わない（Sakuyaと同じ）。
/// 等しさには含める。同じ呼び出しの中（読み始めの位置が同じ）では、木が同じなら
/// Triviaも同じになる（Triviaは葉と葉のすき間にしか現れない）ので、重複の判定や曖昧性は
/// 変わらない。読み始めの位置が違う候補（反復の各回の履歴など）は、木が同じでも
/// Triviaが違うことがあるので、等しさに含めないと別の回のTriviaを取り違える。
///
struct Candidate : Hashable {

	/// まだSourceNodeにしていない木の列。
	var trees: ListID<TreeID>

	/// この比較範囲で通った要素。
	var atoms: ListID<Atom> = .empty

	/// 閉じた子の比較範囲の履歴。字句などの葉も一つずつ持つ。
	var selections: ListID<SelectionID> = .empty

	/// この比較範囲で加えた順位の合計。
	var rank: Int = 0

	/// 反復の途中の回の履歴（最後の回）。Repeatの呼び出しの中でだけ使う。
	var iterations: IterationID? = nil

	/// 自動Triviaで読み飛ばした範囲の列。入力の順。
	var trivia: ListID<TriviaSpan> = .empty

	/// 何も読んでいない候補。
	static var empty: Self {
		.init(trees: .empty)
	}

}


/// 自動Triviaで読み飛ばした範囲。読み飛ばしを求めた文法と、原文の絶対UTF-8範囲。
struct TriviaSpan : Hashable, Sendable {
	let grammar: GrammarID
	let begin: Int
	let end: Int
	/// 直前の範囲と同じ読み飛ばしの続きなら `true`。
	let continuing: Bool
}


/// 比較範囲の識別。
enum Scope : Hashable, Sendable {

	/// 範囲を持たない子（字句など）。
	case leaf

	/// ルール
	case rule(RuleID)

	/// Sequence
	case sequence(Location)

	/// Optional（本文ありと本文なしの選択）
	case optional(Location)

	/// Optionalの本文
	case optionalBody(Location)

	/// Repeat全体
	case loop(Location)

	/// 本文を `count` 回読んだ後の「続けるか終えるか」の選択
	case loopControl(Location, count: Int)

	/// 反復の一回分の本文
	case iteration(Location)

	/// List
	case list(Location)

	/// Atomicの本文（子の確定範囲の入口）
	case atomic(Location)

}


/// 比較範囲で通った要素の識別。
enum Atom : Hashable, Sendable {

	/// ラベルのない字句。同じパターンなら場所によらず同じ。
	case pattern(
		PatternKey,
		spacious: Bool,
		words: [String]?,
		caseInsensitive: Bool,
	)

	/// ラベル付きの字句。命令の場所で区別する。
	case place(Location)

	/// 後方参照。同じ文法・同じtagなら場所によらず同じ。
	case reference(GrammarID, tag: String, spacious: Bool)

	/// 明示Trivia。場所によらず同じ。
	case trivia

	/// Atomicで確定した結果。命令の場所で区別する。
	case atomic(Location)

	/// 閉じた子の比較範囲
	case scope(Scope)

}


/// 選択履歴の番号。
struct SelectionID : Hashable, Sendable {
	let rawValue: Int
}


/// 閉じた比較範囲ひとつ分の選択履歴。
struct Selection : Hashable {
	let scope: Scope
	let atoms: ListID<Atom>
	let rank: Int
	let children: ListID<SelectionID>
}


/// 反復の履歴の番号。
struct IterationID : Hashable, Sendable {
	let rawValue: Int
}


/// 反復の一回分の履歴。前の回をたどると、最初の回まで戻れる。
struct Iteration : Hashable {
	let previous: IterationID?
	/// 最初の回から数えた回数
	let depth: Int
	/// 「続けるか終えるか」の比較範囲
	let control: Scope
	/// 続けたことの順位
	let rank: Int
	/// 本文の候補
	let body: Candidate
}


/// 2つの候補の比較の結果。
enum Ordering {
	case better
	case worse
	case same
	case unordered
}


extension Store {

	/// 選択履歴を左から比べ、最初の差で優劣を決める。
	///
	/// 1. 列の長さが違えば比較不能。
	/// 2. 同じ位置の選択履歴で、比較範囲が違えば比較不能。
	/// 3. Atomか順位が違えば、順位の大きいほうが優る。順位が同じなら比較不能。
	/// 4. Atomも順位も同じなら、子の選択履歴を同じ規則で比べてから、次へ進む。
	/// 5. 最後まで差がなければ同値。
	func compare(
		_ left: ListID<SelectionID>,
		_ right: ListID<SelectionID>,
	) -> Ordering {
		// 比べる列の対を積む。子の列は、兄弟の残りより先に比べる。
		var pending: [(ArraySlice<SelectionID>, ArraySlice<SelectionID>)] = []

		guard
			let first = pair(left, right)
		else { return .unordered }

		pending.append(first)

		while let (lefts, rights) = pending.popLast() {
			guard
				let a: SelectionID = lefts.first,
				let b: SelectionID = rights.first
			else { continue }

			pending.append((lefts.dropFirst(), rights.dropFirst()))

			if a == b {
				continue
			}

			let x: Selection
			= self[a]

			let y: Selection
			= self[b]

			guard
				x.scope == y.scope
			else { return .unordered }

			if x.atoms != y.atoms || x.rank != y.rank {
				if x.rank > y.rank {
					return .better
				}

				if x.rank < y.rank {
					return .worse
				}

				return .unordered
			}

			guard
				let children = pair(x.children, y.children)
			else { return .unordered }

			pending.append(children)
		}

		return .same
	}

	/// 長さが同じなら、2つの列の要素を並べて返す。
	private func pair(
		_ left: ListID<SelectionID>,
		_ right: ListID<SelectionID>,
	) -> (ArraySlice<SelectionID>, ArraySlice<SelectionID>)? {
		let lefts: [SelectionID]
		= selectionLists.elements(left)

		let rights: [SelectionID]
		= selectionLists.elements(right)

		guard
			lefts.count == rights.count
		else { return nil }

		return (lefts[...], rights[...])
	}

}


extension Store {

	/// 反復の途中の回の履歴を、最初の回から比べる。
	///
	/// 共通の前半は飛ばし、最初に違う回で決める。回の比べ方は、比較範囲・順位・
	/// 本文の選択履歴の順。本文の選択履歴が同値でも本文が違えば比較不能。
	/// 比べた回に差がなく回数だけが違えば、残りの回では決められないので比較不能。
	func compareHistories(
		_ left: IterationID?,
		_ right: IterationID?,
	) -> Ordering {
		if left == right {
			return .same
		}

		// 回数をそろえながら、共通の前半までさかのぼる。違う部分を後ろの回から集める。
		var a: IterationID? = left
		var b: IterationID? = right
		var lefts: [IterationID] = []
		var rights: [IterationID] = []

		while a != b {
			let depthA: Int
			= depth(a)

			let depthB: Int
			= depth(b)

			if depthA >= depthB, let id: IterationID = a {
				lefts.append(id)
				a = self[id].previous
			}

			if depthB >= depthA, let id: IterationID = b {
				rights.append(id)
				b = self[id].previous
			}
		}

		for (x, y) in zip(lefts.reversed(), rights.reversed()) {
			let p: Iteration
			= self[x]

			let q: Iteration
			= self[y]

			guard
				p.control == q.control
			else { return .unordered }

			if p.rank != q.rank {
				return p.rank > q.rank ? .better : .worse
			}

			let order: Ordering
			= compare(p.body.selections, q.body.selections)

			guard
				order == .same
			else { return order }

			guard
				p.body == q.body
			else { return .unordered }
		}

		return lefts.count == rights.count ? .same : .unordered
	}

	/// 履歴の回数。履歴がなければ0。
	private func depth(
		_ id: IterationID?,
	) -> Int {
		id.map { self[$0].depth } ?? 0
	}

}
