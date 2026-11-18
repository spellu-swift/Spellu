import Basis
import SpelluLex


extension SpelluGrammar {

	/// 同一文法の固定字句を、競合する接頭辞の境界で展開する。
	/// 文字集合・可変長の反復と外部文法の参照は変更しない。
	static func precompile(
		_ rules: [SpelluRule],
	) -> [SpelluRule] {
		var compiler: PrefixCompiler = .init()

		for rule: SpelluRule in rules {
			compiler.collect(rule.syntax.ir)
		}

		compiler.partition()

		return rules.map { rule in
			.init(
				name: rule.name,
				label: rule.label,
				expose: rule.expose,
				syntax: Syntax { compiler.rewrite(rule.syntax.ir) },
			)
		}
	}

}


/// 認識に同じ文字列を使う字句は、同じ分割境界を共有する。
private struct PrefixCompiler {

	struct Literal: Hashable {
		let scalars: [UInt32]
		let insensitive: Bool
	}

	struct Plan {
		let literal: Literal
		var cuts: Set<Int>
		var affected: Bool = false
	}

	struct Piece {
		let plan: Int
		let begin: Int
		let end: Int
	}

	var plans: [Plan] = []
	var ids: [Literal: Int] = [:]

	/// 一回だけ読む固定文字列。診断は変更しない。
	func literal(_ pattern: TokenIR) -> Literal? {
		guard
			pattern.amount == .exactly(1),
			pattern.expect == nil
		else {
			return nil
		}

		let insensitive: Bool = pattern.caseInsensitive ?? false

		guard
			let scalars: [UInt32] = scalars(pattern, inherited: insensitive),
			scalars.isNotEmpty
		else { return nil }

		return .init(scalars: scalars, insensitive: insensitive)
	}

	func scalars(_ pattern: TokenIR, inherited: Bool) -> [UInt32]? {
		guard
			pattern.amount == .exactly(1),
			pattern.expect == nil,
			pattern.behavior != .possessive,
			(pattern.caseInsensitive ?? inherited) == inherited
		else { return nil }

		switch pattern.factor {
			case let .string(string):
				return string.unicodeScalars.map {
					inherited
						? UnicodeProperty.SimpleCaseFolding.folded($0.value)
						: $0.value
				}
			case let .sequence(children):
				var result: [UInt32] = []
				for child: TokenIR in children {
					guard let value = scalars(child, inherited: inherited)
					else { return nil }
					result += value
				}
				return result
			case .character, .alternative:
				return nil
		}
	}

	mutating func collect(_ body: [SyntaxIR]) {
		for ir: SyntaxIR in body {
			switch ir {
				case let .token(_, pattern, _, _):
					if let key: Literal = literal(pattern), ids[key] == nil {
						ids[key] = plans.count
						plans.append(.init(
							literal: key, cuts: [0, key.scalars.count],
						))
					}
				case let .sequence(_, body), let .choiceOf(body),
					let .optional(body), let .atomic(body),
					let .repeat(body, _, _), let .capture(body):
					collect(body)
				case let .anyOf(branches):
					for branch in branches { collect(branch.body) }
				case let .list(value, separator, _, _):
					collect(value)
					collect(separator)
				case let .enclosure(body, _, _, opener, closer):
					collect(body)
					collect(opener)
					collect(closer)
				case	let .relabel(_, value):
					collect([value])
				case .word, .trivia, .ruleref, .tokenref:
					break
			}
		}
	}

	/// 切り出した後半同士も調べ、分割位置が増えなくなるまで続ける。
	mutating func partition() {
		var changed: Bool = true
		while changed {
			changed = false
			var pieces: [Piece] = []
			for index: Int in plans.indices {
				let cuts: [Int] = plans[index].cuts.sorted()
				for (begin, end) in zip(cuts, cuts.dropFirst()) {
					pieces.append(.init(plan: index, begin: begin, end: end))
				}
			}
			for leftIndex: Int in pieces.indices {
				let left: Piece = pieces[leftIndex]
				let lhs: Literal = plans[left.plan].literal
				for right: Piece in pieces.dropFirst(leftIndex + 1) {
					let rhs: Literal = plans[right.plan].literal
					guard lhs.insensitive == rhs.insensitive else { continue }
					let length: Int = min(
						left.end - left.begin, right.end - right.begin,
					)
					var common: Int = 0
					while common < length,
						lhs.scalars[left.begin + common]
							== rhs.scalars[right.begin + common] {
						common += 1
					}
					guard common > 0 else { continue }
					if common == left.end - left.begin,
						common == right.end - right.begin { continue }
					plans[left.plan].affected = true
					plans[right.plan].affected = true
					changed = plans[left.plan].cuts
						.insert(left.begin + common).inserted || changed
					changed = plans[right.plan].cuts
						.insert(right.begin + common).inserted || changed
				}
			}
		}
	}

	func parts(_ plan: Plan) -> [TokenIR] {
		let cuts: [Int] = plan.cuts.sorted()
		return zip(cuts, cuts.dropFirst()).map { begin, end in
			let scalars: [UnicodeScalar]
			= plan.literal.scalars[begin..<end].map { UnicodeScalar($0)! }
			return .string(
				String(String.UnicodeScalarView(scalars)),
				caseInsensitive: plan.literal.insensitive ? true : nil,
			)
		}
	}

	func rewrite(_ body: [SyntaxIR]) -> [SyntaxIR] {
		body.map { ir in
			switch ir {
				case let .token(label, pattern, spacious, tag):
					// tagは元の字句全体を記録するため、分割しない。
					guard tag == nil else { return ir }
					guard let key: Literal = literal(pattern),
						let index: Int = ids[key], plans[index].affected
					else { return ir }
					let fragments: [TokenIR] = parts(plans[index])
					guard fragments.count > 1 else { return ir }
					return .sequence(label, fragments.enumerated().map { index, part in
						.token(.none, [part], spacious: index == 0 && spacious)
					})
				case let .sequence(label, body):
					return .sequence(label, rewrite(body))
				case let .choiceOf(body): return .choiceOf(rewrite(body))
				case let .anyOf(branches):
					return .anyOf(branches.map {
						.init(precedence: $0.precedence, body: rewrite($0.body))
					})
				case let .optional(body): return .optional(rewrite(body))
				case let .atomic(body): return .atomic(rewrite(body))
				case let .repeat(body, amount, behavior):
					return .repeat(rewrite(body), amount, behavior: behavior)
				case let .list(value, separator, last, amount):
					return .list(
						rewrite(value), rewrite(separator),
						lastSeparator: last, amount,
					)
				case let .enclosure(body, amount, behavior, opener, closeer):
					return .enclosure(rewrite(body), amount: amount, behavior: behavior, opener: rewrite(opener), closer: rewrite(closeer))
				case let .capture(body):
					return .capture(rewrite(body))
				case let .relabel(label, value):
					return .relabel(label: label, rewrite([value])[0])
				case .word, .trivia, .ruleref, .tokenref:
					return ir
			}
		}
	}

}
