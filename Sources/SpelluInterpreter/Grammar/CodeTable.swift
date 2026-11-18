import Basis
import SpelluCore
import SpelluLex


/// 文法の番号。
struct GrammarID : Hashable, Sendable {
	let rawValue: Int
}


/// ルールの番号。
struct RuleID : Hashable, Sendable {
	let rawValue: Int
}


/// 命令列（`[SyntaxIR]`）の番号。
struct BlockID : Hashable, Sendable {
	let rawValue: Int
}


/// 字句の番号。字句・Wordの命令に、表を作るときに振る連番。
/// 照合に使うProgram（Momojiri）を、字句ごとに一度だけ作るのに使う。
struct TokenID : Hashable, Sendable {
	let rawValue: Int
}


/// 命令の場所。`pc` が命令列の長さと等しければ、命令列の終わりを指す。
struct Location : Hashable, Sendable {
	let block: BlockID
	let pc: Int

	/// 次の命令の場所。
	var next: Self {
		.init(block: block, pc: pc + 1)
	}
}


///
/// 命令列の表
///
/// SyntaxIRはenumなので、そのままでは「文法のどこにいるか」を値として比べられない。
/// 初期化時に命令列ごとに番号を振り、命令の場所を `Location` で表せるようにする。
/// SyntaxIRを別の形へ変換することはしない。
///
struct CodeTable : Sendable {

	struct Block : Sendable {
		let grammar: GrammarID
		let code: [SyntaxIR]
	}

	struct Grammar : Sendable {
		let name: String
		let rules: [String: RuleID]
		/// 開始ルールを省略したときの入口。最初の公開ルール。
		let entry: RuleID?
		/// 字句Trivia（空白など）のパターン。
		let lexicalTrivia: [TokenIR]
		/// 構文Triviaの命令列。構文Triviaひとつにつき `[SyntaxIR]` 一つ。
		let syntaxTrivia: [BlockID]

		/// 自動Triviaを読む文法か。
		var hasTrivia: Bool {
			!lexicalTrivia.isEmpty || !syntaxTrivia.isEmpty
		}
	}

	struct Rule : Sendable {
		let grammar: GrammarID
		let name: String
		/// ルールのノードのラベル。
		let label: Label
		let body: BlockID
	}

	let blocks: [Block]
	let grammars: [Grammar]
	let rules: [Rule]
	/// 複合の命令が持つ子の命令列。例：Sequenceの本文、ChoiceOfの各枝。
	let children: [Location: [BlockID]]
	/// ルール参照の参照先。
	let references: [Location: RuleID]
	/// 複製した命令列の区間と、その元の命令列（Listの選択肢）。
	let segments: [BlockID: [Segment]]
	/// 字句・Wordの命令の番号。複製した命令は元の場所の番号を使う。
	let tokens: [Location: TokenID]

	/// 複製した命令列の一区間。`range` の命令は、`origin` の `start` から始まる命令の複製。
	struct Segment : Sendable {
		let range: Range<Int>
		let origin: BlockID
		let start: Int
	}

	/// 命令の元の場所。複製した命令なら元の命令の場所、そうでなければそのまま。
	///
	/// Listの選択肢は要素などの命令を複製して作る。複製した命令でも、呼び出し・
	/// 比較範囲・Atomの識別には元の場所を使い、元の命令と共有する。
	/// スロット（ディスクリプタの位置）は複製した場所のままにする。
	func canonical(
		_ location: Location,
	) -> Location {
		Self.canonical(location, in: segments)
	}

	static func canonical(
		_ location: Location,
		in segments: [BlockID: [Segment]],
	) -> Location {
		guard
			let segment: Segment = segments[location.block]?.first(where: {
				$0.range.contains(location.pc)
			})
		else { return location }

		return .init(
			block: segment.origin,
			pc: segment.start + location.pc - segment.range.lowerBound,
		)
	}

	subscript(
		block: BlockID,
	) -> Block {
		blocks[block.rawValue]
	}

	subscript(
		grammar: GrammarID,
	) -> Grammar {
		grammars[grammar.rawValue]
	}

	subscript(
		rule: RuleID,
	) -> Rule {
		rules[rule.rawValue]
	}

	/// 場所の命令。命令列の終わりなら `nil`。
	func instruction(
		at location: Location,
	) -> SyntaxIR? {
		let code: [SyntaxIR]
		= self[location.block].code

		return location.pc < code.count ? code[location.pc] : nil
	}

	/// 字句・Wordの命令の番号。`location` は元の命令の場所。
	func token(
		at location: Location,
	) throws -> TokenID {
		guard
			let token: TokenID = tokens[location]
		else {
			throw SpelluError.internalError(
				"Interpreter token has no number",
			)
		}

		return token
	}

	/// 命令が属する文法。
	func grammar(
		of location: Location,
	) -> GrammarID {
		self[location.block].grammar
	}

	/// 開始ルール。省略したときは、最初の文法の最初の公開ルール。
	func start(
		_ reference: RuleReference?,
	) throws -> RuleID {
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
			let grammar: Grammar = grammars.first(where: { $0.name == name })
		else { throw SpelluError.grammarNotFound(grammar: name) }

		guard
			let reference
		else {
			guard
				let entry: RuleID = grammar.entry
			else { throw SpelluError.noExposedRule(grammar: name) }

			return entry
		}

		guard
			let rule: RuleID = grammar.rules[reference.rule]
		else {
			throw SpelluError.ruleNotFound(
				grammar: name,
				rule: reference.rule,
			)
		}

		return rule
	}

}
