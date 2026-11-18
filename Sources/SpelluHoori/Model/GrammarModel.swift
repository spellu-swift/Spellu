import Basis
import SpelluCore
import SpelluLex


/// 入力に依存しない、Earley法の実行用に平坦化した文法表。
///
/// 生成規則の右辺を `symbols` に連結し、項目のドット位置はその添字で表す。
/// ドットの次の記号は `symbols[dot]` の一回の参照で得られる。
struct GrammarModel : Sendable {

	/// 右辺の一記号。各生成規則の末尾には `end` を置く。
	enum Symbol : Sendable {
		case nonterminal(Int32, SpanCondition)
		case lexeme(Int32)
		case reference(Int32)
		case boundary(Int32)
		case trivia(Int32)
		case eos(silent: Bool)
		case point(Int32)
		case never(silent: Bool)
		case end(Int32)
	}

	/// 非終端記号の範囲で、項目を進めてよいかの条件。
	enum SpanCondition : Sendable {
		case none
		case nonEmpty
		case emptyOnly
		/// 必須回数未満の反復の本文。空なら回数を上限と照合する。
		case required(Int32)
		/// 明示Triviaの本文。空なら不一致として記録する。
		case explicitTrivia(silent: Bool)
	}

	enum NonterminalKind : Sendable {
		/// 比較範囲を閉じる。labelが0以上なら構文ノードを作る。
		case scoped(scope: Int32, label: Int32)
		/// 順位とAtomを外側の範囲へ渡す。
		case transparent
		/// 終了時に出力環境を入口の環境へ戻す。
		case capture
		/// 返された最上位の木のラベルを変更する。
		case relabel(label: Int32)
		/// 反復のk回目までの前半。
		case loopPrefix
		/// 反復全体。継続・終了の選択を畳み込んで比較範囲を閉じる。
		case loop(scope: Int32)
		/// 自動Trivia。木も順位も持たない。
		case skip
		/// 明示Trivia。範囲全体を一つの葉にする。
		case explicitTrivia
		/// 全体一致の合成された開始記号。
		case whole
	}

	enum ProductionAction : Sendable {
		case join
		/// 反復の一回分を前半へ加える。controlは継続の判断の比較範囲。
		case iterate(control: Int32)
		/// 前半で反復を終える。
		case stop(control: Int32)
		/// 上限回数に達して反復を終える。
		case limit
		/// 空の本文を最後の一回として反復を終える。
		case final(control: Int32)
	}

	struct Production : Sendable {
		let lhs: Int32
		let first: Int32
		let rank: Int32
		let action: ProductionAction
	}

	struct Nonterminal : Sendable {
		let kind: NonterminalKind
		let grammar: Int32
		/// ルールの本体か。導出の循環は必ずルールを通るので、ここで打ち切る。
		var isRule: Bool = false
		var productions: Range<Int32> = 0..<0
	}

	/// 字句の記号位置。照合方法は走査クラスで共有し、ラベルとtagは位置ごとに持つ。
	struct Lexeme : Sendable {
		let scanClass: Int32
		let label: Int32
		let tag: Int32
		let atom: Int32
		let grammar: Int32
		let silent: Bool
	}

	/// 照合結果を `(クラス, 位置)` で共有する単位。
	struct ScanClass : Sendable {
		let program: Int32
		/// 字句の前に読むTriviaのProgram。なければ-1。
		let prefix: Int32
		let hasWords: Bool
	}

	/// 走査クラスの失敗時とWordの検査でだけ使う情報。
	struct ScanDetail : Sendable {
		let pattern: TokenIR
		let words: [String]?
		let insensitive: Bool
	}

	struct Reference : Sendable {
		let tag: Int32
		let atom: Int32
		let grammar: Int32
		let silent: Bool
	}

	struct Point : Sendable {
		let atom: Int32
		let grammar: Int32
	}

	struct TriviaScan : Sendable {
		let optional: Int32
		let required: Int32
		let silent: Bool
	}

	struct Boundary : Sendable {
		let entry: Int32
		let atom: Int32
		let probe: Bool
	}

	struct Grammar : Sendable {
		let name: String
		let rules: [String: Int32]
		let entry: Int32?
	}

	struct Rule : Sendable {
		let grammar: Int32
		let name: String
		let exposed: Bool
		let nonterminal: Int32
		let whole: Int32
	}

	let symbols: [Symbol]
	/// ドット位置が属する生成規則。
	let owners: [Int32]
	let productions: [Production]
	/// 非終端記号の `productions` が指す、実行時に予測する生成規則の番号。
	let productionOrder: [Int32]
	let nonterminals: [Nonterminal]
	let lexemes: [Lexeme]
	let scanClasses: [ScanClass]
	let scanDetails: [ScanDetail]
	let references: [Reference]
	let points: [Point]
	let triviaScans: [TriviaScan]
	let boundaries: [Boundary]
	let programs: [TokenProgram]
	let labels: [Label]
	let noneLabel: Int32
	let nilLabel: Int32
	let triviaLabel: Int32
	let triviaAtom: Int32
	let tags: [String]
	let rules: [Rule]
	let grammars: [Grammar]
	let grammarNames: [String: Int32]

	func start(
		_ reference: RuleReference?,
	) throws -> Int32 {
		guard
			let first: Grammar = grammars.first
		else {
			throw SpelluError.grammarNotFound(
				grammar: reference?.grammar ?? "",
			)
		}

		let name: String
		= reference?.grammar ?? first.name

		guard
			let owner: Int32 = grammarNames[name]
		else { throw SpelluError.grammarNotFound(grammar: name) }

		let grammar: Grammar
		= grammars[Int(owner)]

		if let reference {
			guard
				let rule: Int32 = grammar.rules[reference.rule]
			else {
				throw SpelluError.ruleNotFound(
					grammar: name,
					rule: reference.rule,
				)
			}

			return rule
		}

		guard
			let entry: Int32 = grammar.entry
		else { throw SpelluError.noExposedRule(grammar: name) }

		return entry
	}

}
