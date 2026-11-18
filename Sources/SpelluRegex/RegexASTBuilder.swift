import SpelluCore


/// SourceNodeの子を使い、原文全体の再解析をせずASTを組み立てる。
@available(macOS 15, iOS 18, *)
struct RegexASTBuilder {

	let options: Options
	var ast: RegexAST = .init()

	init(options: Options) {
		self.options = options
	}

	struct Tree {
		let parent: Int?
		let source: SourceNode
		let inClass: Bool
		let capture: Int?
		var children: [Int] = []
	}

	private enum Value {
		case node(Int)
		case character(RegexCharacter)
		case quantifier(RegexQuantifier)
		case modifiers(RegexModifiers)
	}

	mutating func build(_ source: SourceNode) throws -> RegexAST {
		var tree: [Tree] = []
		var work: [(SourceNode, Int?, Bool)] = [(source, nil, false)]
		while let (node, parent, inheritedClass) = work.popLast() {
			guard tree.count < options.limits.maximumNodes else {
				throw SpelluRegexError.resourceLimit("構文ノード数")
			}
			let inClass: Bool
			= inheritedClass || node.label.string == "characterClass"
			let capture: Int?
			if node.label.string == "capture"
				|| node.label.string == "namedCapture" {
				guard ast.captureCount < options.limits.maximumCaptures else {
					throw SpelluRegexError.resourceLimit("捕捉数")
				}
				capture = ast.captureCount
				ast.captureCount += 1
			} else { capture = nil }
			let index: Int = tree.count
			tree.append(.init(
				parent: parent, source: node, inClass: inClass, capture: capture,
			))
			if let parent { tree[parent].children.append(index) }
			for child: SourceNode in node.parts.reversed() {
				work.append((child, index, inClass))
			}
		}
		try registerNames(tree)
		var values: [[Value]] = .init(repeating: [], count: tree.count)
		for index: Int in tree.indices.reversed() {
			let item: Tree = tree[index]
			let children: [Value] = item.children.flatMap { values[$0] }
			values[index] = try convert(item, children: children)
		}
		guard case let .node(root)? = values[0].first else {
			throw invalid(source, "正規表現の開始規則が必要です。")
		}
		ast.root = root
		return ast
	}

	private mutating func convert(
		_ item: Tree,
		children: [Value],
	) throws -> [Value] {
		let source: SourceNode = item.source
		let nodes: [Int] = children.compactMap {
			if case let .node(index) = $0 { return index }
			return nil
		}
		let characters: [RegexCharacter] = children.compactMap {
			if case let .character(value) = $0 { return value }
			return nil
		}
		switch source.label.string {
			case "literal", "classLiteral":
				return [.character(.scalar(source.substring.unicodeScalars.first!.value))]
			case "escape":
				return [.character(try escape(source, inClass: item.inClass))]
			case "reference":
				return [.node(ast.append(.reference(try reference(source))))]
			case "boundary":
				return [.node(ast.append(.boundary(source.string == "\\b")))]
			case "modifierFlags":
				return [.modifiers(try modifiers(source))]
			case "dot": return [.character(.dot)]
			case "assertion":
				return [.node(ast.append(.assertion(source.string == "^")))]
			case "quantifier":
				return [.quantifier(try quantifier(source))]
			case "classAtom": return children
			case "classItem":
				if characters.count == 2 {
					guard let first: UInt32 = characters[0].scalarValue,
						let last: UInt32 = characters[1].scalarValue,
						first <= last
					else { throw invalid(source, "文字範囲の端点が不正です。") }
					return [.character(.range(first...last))]
				}
				return children
			case "characterClass":
				let union: RegexCharacter = .union(characters)
				return [.node(ast.append(.character(
					source.string.hasPrefix("[^") ? .inverted(union) : union
				)))]
			case "atom":
				if let node: Int = nodes.first { return [.node(node)] }
				return [.node(ast.append(.character(characters[0])))]
			case "capture", "namedCapture":
				return [.node(ast.append(
					.capture(item.capture!, nodes[0]),
					children: nodes, capture: item.capture,
				))]
			case "nonCapture": return [.node(nodes[0])]
			case "lookahead":
				return [.node(ast.append(
					.lookahead(nodes[0], positive: source.string.hasPrefix("(?=")),
					children: nodes,
				))]
			case "modifiedGroup":
				let change: RegexModifiers = children.compactMap {
					if case let .modifiers(value) = $0 { return value }
					return nil
				}.first!
				return [.node(ast.append(
					.modifiers(nodes[0], change), children: nodes,
				))]
			case "extensionGroup":
				throw SpelluRegexError.unsupportedFeature(
					range: source.range, feature: "lookbehind",
				)
			case "term":
				if let quantifier: RegexQuantifier = children.compactMap({
					if case let .quantifier(value) = $0 { return value }
					return nil
				}).first {
					return [.node(ast.append(
						.repetition(nodes[0], quantifier), children: nodes,
					))]
				}
				return [.node(nodes[0])]
			case "alternative":
				return [.node(ast.append(.sequence(nodes), children: nodes))]
			case "expression":
				return [.node(ast.append(.choice(nodes), children: nodes))]
			default: return children
		}
	}

	private func quantifier(
		_ source: SourceNode,
	) throws -> RegexQuantifier {
		var text: String = source.string
		let greedy: Bool = !(text.count > 1 && text.hasSuffix("?"))
		if !greedy { text.removeLast() }
		switch text {
			case "*": return .init(minimum: 0, maximum: nil, greedy: greedy)
			case "+": return .init(minimum: 1, maximum: nil, greedy: greedy)
			case "?": return .init(minimum: 0, maximum: 1, greedy: greedy)
			default: break
		}
		let bounds: [Substring] = text.dropFirst().dropLast().split(
			separator: ",", omittingEmptySubsequences: false,
		)
		guard let minimum: Int = Int(bounds[0]) else {
			throw SpelluRegexError.resourceLimit("量指定の整数範囲")
		}
		let maximum: Int?
		if bounds.count == 1 { maximum = minimum }
		else if bounds[1].isEmpty { maximum = nil }
		else {
			guard let value: Int = Int(bounds[1]) else {
				throw SpelluRegexError.resourceLimit("量指定の整数範囲")
			}
			maximum = value
		}
		guard maximum.map({ minimum <= $0 }) ?? true else {
			throw invalid(source, "量指定の最小値が最大値を超えています。")
		}
		return .init(minimum: minimum, maximum: maximum, greedy: greedy)
	}

	private func escape(
		_ source: SourceNode,
		inClass: Bool,
	) throws -> RegexCharacter {
		let raw: String = source.string
		let body: String = String(raw.dropFirst())
		let scalars: [UnicodeScalar] = Array(body.unicodeScalars)
		let first: UInt32 = scalars[0].value
		switch first {
			case 100, 68: return .shorthand(100, inverted: first == 68)
			case 119, 87: return .shorthand(119, inverted: first == 87)
			case 115, 83: return .shorthand(115, inverted: first == 83)
			case 112, 80:
				guard body.hasPrefix("p{") || body.hasPrefix("P{"),
					body.hasSuffix("}")
				else { throw invalid(source, "Property escapeが不正です。") }
				let name: String = String(body.dropFirst(2).dropLast())
				return .property(try RegexProperty.resolve(
					name, semantics: options.characterSemantics,
					range: source.range,
				), inverted: first == 80)
			case 110: return .scalar(10)
			case 114: return .scalar(13)
			case 116: return .scalar(9)
			case 118: return .scalar(11)
			case 102: return .scalar(12)
			case 98 where inClass: return .scalar(8)
			case 98, 66, 107, 49...57:
				throw invalid(source, "uモードのescapeが不正です。")
			case 48:
				let after: String.Index = source.source.content.utf8.index(
					source.source.content.utf8.startIndex,
					offsetBy: source.end,
				)
				if after < source.source.content.endIndex,
					(48...57).contains(
						source.source.content.unicodeScalars[after].value
					) {
					throw invalid(source, "uモードでは8進escapeを使えません。")
				}
				return .scalar(0)
			case 99:
				guard scalars.count == 2,
					(65...90).contains(scalars[1].value)
						|| (97...122).contains(scalars[1].value)
				else { throw invalid(source, "Control escapeが不正です。") }
				return .scalar(scalars[1].value % 32)
			case 117, 120:
				guard let value: UInt32 = RegexEscapedScalar.value(raw) else {
					throw invalid(source, "Unicode／hex escapeが不正です。")
				}
				guard UnicodeScalar(value) != nil else {
					throw SpelluRegexError.unsupportedFeature(
						range: source.range, feature: "孤立サロゲート",
					)
				}
				return .scalar(value)
			default:
				let escaped: String = "^$\\.*+?()[]{}|/" + (inClass ? "-" : "")
				guard escaped.unicodeScalars.contains(scalars[0]) else {
					throw invalid(source, "uモードのescapeが不正です。")
				}
				return .scalar(first)
		}
	}

	func invalid(
		_ node: SourceNode,
		_ message: String,
	) -> SpelluRegexError {
		.invalidPattern(range: node.range, message: message)
	}

	/// v2へ渡す前に入力長と入れ子を制限する。escape内は数えない。
	static func checkInput(
		_ pattern: String,
		limits: RegexLimits,
	) throws {
		var count: Int = 0
		var depth: Int = 0
		var inClass: Bool = false
		var escaped: Bool = false
		for scalar: UnicodeScalar in pattern.unicodeScalars {
			guard count < limits.maximumPatternScalars else {
				throw SpelluRegexError.resourceLimit("pattern長")
			}
			count += 1
			if escaped { escaped = false; continue }
			if scalar == "\\" { escaped = true; continue }
			if inClass {
				if scalar == "]" { inClass = false }
				continue
			}
			if scalar == "[" { inClass = true }
			if scalar == "(" {
				guard depth < limits.maximumNesting else {
					throw SpelluRegexError.resourceLimit("入れ子の深さ")
				}
				depth += 1
			}
			if scalar == ")" { depth = max(0, depth - 1) }
		}
	}

}
