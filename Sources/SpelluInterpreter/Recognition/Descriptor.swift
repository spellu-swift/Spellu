import SpelluCore


/// 呼び出す構文。GSSノードの「何を呼んだか」に当たる。
enum Construct : Hashable, Sendable {

	/// ルール。比較範囲を閉じ、ルールのノードを作る。
	case rule(RuleID)

	/// Sequence。比較範囲を閉じ、ノードを作る。
	case sequence(Location)

	/// ChoiceOf・AnyOf。各枝を選択肢にし、枝の順位を外の比較範囲へ渡す。
	case choice(Location)

	/// Optional。本文あり（順位1）と本文なし（順位0）の選択肢を持ち、比較範囲を閉じる。
	case optional(Location)

	/// Optionalの本文。比較範囲を閉じる。
	case optionalBody(Location)

	/// Repeat。反復の位置（`Slot.loop`）を進め、比較範囲を閉じる。
	case `repeat`(Location)

	/// 反復の一回分の本文。比較範囲を閉じる。
	case iteration(Location)

	/// List。空・「要素＋残り」・「要素＋残り＋区切り」の補助の命令列を選択肢にし、
	/// 比較範囲を閉じる。
	case list(Location)

	/// Enclosure。「開始＋反復＋終了」の補助の命令列を実行し、候補をそのまま渡す。
	case enclosure(Location)

	/// Capture。本文を実行し、完了時にタグ環境を呼び出し時の環境へ戻す。候補はそのまま渡す。
	case capture(Location)

	/// Relabel。子を実行し、返った木の一番上のラベルを付け替える。候補はそのまま渡す。
	case relabel(Location)

	/// Atomicの本文。子の確定範囲の入口になる。
	/// 比較範囲を閉じ、ノードを作る（`#atomic`）。
	case atomicBody(Location)

	/// 自動Trivia。字句Triviaと、構文Triviaの繰り返しを読む。
	/// 読んだ位置とタグ環境だけを使い、木と順位は使わない。
	case trivia(GrammarID)

	/// 構文Triviaのひとつ。Triviaの照合中のモードで読む。
	case syntaxTrivia(GrammarID, index: Int)

	/// 全体一致の入口。開始ルールを読み、末尾の自動Triviaを読んで、入力の終端を確かめる。
	/// 候補はそのまま渡す。
	case whole(RuleID)

}


/// GLLのスロット。文法の中の位置を表す。
enum Slot : Hashable, Sendable {

	/// 命令列の中の位置。
	case code(Location)

	/// Optionalの選択肢の中の位置。
	case optional(Location, OptionalStep)

	/// 反復の本文を `count` 回読み終えた位置。
	case loop(Location, count: Int)

	/// 本文を `count` 回読んだ後、空の回を最後の回として読み終えた位置。
	case final(Location, count: Int)

	/// 自動Triviaの中の位置。
	case trivia(GrammarID, TriviaStep)

	/// 命令の前の自動Triviaを読み終え、命令の本体を実行する位置。
	case afterTrivia(Location)

	/// 全体一致の入口の中の位置。
	case whole(RuleID, WholeStep)

}


/// 全体一致の入口の中の位置。
enum WholeStep : Hashable, Sendable {

	/// 開始ルールを呼ぶ。
	case rule

	/// 開始ルールの文法の自動Triviaを読む。
	case trivia

	/// 入力の終端を確かめる。
	case end

}


/// 自動Triviaの中の位置。
enum TriviaStep : Hashable, Sendable {

	/// 字句Triviaを読む（Triviaの先頭と、構文Triviaの後）。
	case lexical

	/// 構文Triviaをもう一つ読むか、ここで終える。
	case syntax

}


/// Optionalの選択肢の中の位置。
enum OptionalStep : Hashable, Sendable {

	/// 本文を呼ぶ（本文ありの選択肢の先頭）。
	case body

	/// 本文を読み終えた。
	case afterBody

	/// 本文を読まない（本文なしの選択肢）。
	case skipped

}


/// 照合のモード。モードが違えば別の呼び出しになる。
struct Mode : Hashable, Sendable {

	/// Triviaの照合中か。照合中は自動Triviaを挟まない。
	var trivia: Bool = false

	/// 失敗を診断に記録しないか。
	var silent: Bool = false

}


/// tagの識別。tagの記録は文法ごとに分かれる。
struct TagKey : Hashable, Sendable {
	let grammar: GrammarID
	let name: String
}


/// タグ環境。tagで記録した原文の範囲を持つ。
/// 位置が同じでも環境が違えば、別の経路として扱う。
///
/// 環境は呼び出し・ディスクリプタ・結果のキーに入り、何度もハッシュされる。
/// 記録を変えたときにハッシュの値を一度だけ求めておき、それを使う。
struct Environment : Hashable, Sendable {

	private var captures: [TagKey: Range<Int>] = [:]

	/// `captures` のハッシュの値。
	private var digest: Int = 0

	init() {
	}

	static func == (
		left: Self,
		right: Self,
	) -> Bool {
		left.digest == right.digest && left.captures == right.captures
	}

	func hash(
		into hasher: inout Hasher,
	) {
		hasher.combine(digest)
	}

	/// tagで記録した範囲。記録がなければ `nil`。
	func range(
		of tag: TagKey,
	) -> Range<Int>? {
		captures[tag]
	}

	/// tagの記録を置き換えた環境。
	func recording(
		_ range: Range<Int>,
		as tag: TagKey,
	) -> Self {
		var output: Self
		= self

		output.captures[tag] = range
		output.digest = output.captures.hashValue

		return output
	}

}


/// GSSノード。同じ構文を、同じ位置・環境・モードで呼んだものは一つにまとめる。
struct Call : Hashable, Sendable {
	let construct: Construct
	let position: Int
	let environment: Environment
	let mode: Mode
}


/// ディスクリプタ。「どの呼び出しの中で、文法のどこまで、入力のどこまで読んだか」。
/// GLLのSPPFの中間ノードを兼ねる。
struct Descriptor : Hashable, Sendable {
	let slot: Slot
	let call: Call
	let position: Int
	let environment: Environment
}


/// 呼び出しの結果。GLLのSPPFの記号ノードに当たる。
struct CallResult : Hashable, Sendable {
	let call: Call
	let end: Int
	let environment: Environment
}


/// 導出。GLLのSPPFのPackedノードに当たる。
/// 左は一つ前のディスクリプタ、右は直前の命令の結果。
struct Derivation : Hashable, Sendable {
	let left: Descriptor
	let right: Child
}


/// 導出の右の子。直前の命令の結果。
enum Child : Hashable, Sendable {

	/// 呼び出しの結果
	case result(CallResult)

	/// 字句。命令の場所と、読んだ範囲。
	case token(Location, begin: Int, end: Int)

	/// 明示Trivia。範囲全体を一つの葉にする。
	case explicitTrivia(Location, begin: Int, end: Int)

	/// 子の確定範囲で確定した結果。命令の場所と、子が返した木と自動Triviaの列。
	case boundary(
		Location,
		trees: ListID<TreeID>,
		trivia: ListID<TriviaSpan>,
	)

	/// 自動Triviaの結果。木は作らず、読み飛ばした範囲を `SourceTree.trivia` に入れる。
	/// 範囲の列は、認識が終わってから `Evaluation.autoTrivia` に求める。
	case autoTrivia(CallResult)

	/// 木を作らない成功（自動Triviaなど）。
	case nothing

}
