import SpelluCore


@available(macOS 15, iOS 18, *)
extension RegexASTBuilder {

	/// 全捕捉を収集した後に名前を登録し、前方参照も解決可能にする。
	mutating func registerNames(_ tree: [Tree]) throws {
		var positions: [Int: Int] = [:]
		for index: Int in tree.indices {
			if let capture: Int = tree[index].capture { positions[capture] = index }
		}
		for item: Tree in tree where item.source.label.string == "captureName" {
			let name: RegexCaptureName = try .init(
				item.source.string, range: item.source.range,
			)
			var parent: Int? = item.parent
			while let index: Int = parent, tree[index].capture == nil {
				parent = tree[index].parent
			}
			let index: Int = parent!
			let capture: Int = tree[index].capture!
			if let group: Int = ast.namedCaptures.firstIndex(where: {
				$0.name == name
			}) {
				let path: [Int: Int] = alternatives(of: index, in: tree)
				for other: Int in ast.namedCaptures[group].captures {
					let previous: [Int: Int] = alternatives(
						of: positions[other]!, in: tree,
					)
					// 共通の選択規則の別Alternativeに属する場合だけ許す。
					guard path.contains(where: { expression, alternative in
						previous[expression].map { $0 != alternative } ?? false
					}) else {
						throw invalid(item.source, "同時に参加し得る捕捉名が重複しています。")
					}
				}
				ast.namedCaptures[group].captures.append(capture)
			} else {
				ast.namedCaptures.append(.init(name: name, captures: [capture]))
			}
		}
	}

	private func alternatives(
		of index: Int,
		in tree: [Tree],
	) -> [Int: Int] {
		var result: [Int: Int] = [:]
		var alternative: Int? = nil
		var cursor: Int? = index
		while let current: Int = cursor {
			switch tree[current].source.label.string {
				case "alternative": alternative = current
				case "expression":
					if let alternative { result[current] = alternative }
					alternative = nil
				default: break
			}
			cursor = tree[current].parent
		}
		return result
	}

	func reference(_ source: SourceNode) throws -> [Int] {
		if source.string.hasPrefix("\\k<") {
			let name: RegexCaptureName = try .init(
				String(source.string.dropFirst(3).dropLast()),
				range: source.range,
			)
			guard let group: RegexNamedCapture = ast.namedCaptures.first(where: {
				$0.name == name
			}) else { throw invalid(source, "後方参照の捕捉名が存在しません。") }
			return group.captures
		}
		guard let number: Int = Int(source.string.dropFirst()),
			number > 0, number <= ast.captureCount
		else { throw invalid(source, "後方参照の捕捉番号が存在しません。") }
		return [number - 1]
	}

	func modifiers(_ source: SourceNode) throws -> RegexModifiers {
		let parts: [Substring] = source.substring.split(
			separator: "-", omittingEmptySubsequences: false,
		)
		guard parts.count <= 2 else {
			throw invalid(source, "局所修飾子の削除指定が重複しています。")
		}
		var used: Set<UnicodeScalar> = []
		var values: [RegexFlags] = []
		for part: Substring in parts {
			var flags: RegexFlags = []
			for scalar: UnicodeScalar in part.unicodeScalars {
				guard used.insert(scalar).inserted else {
					throw invalid(source, "局所修飾子が重複・衝突しています。")
				}
				switch scalar {
					case "i": flags.insert(.ignoresCase)
					case "m": flags.insert(.multiline)
					case "s": flags.insert(.dotMatchesNewlines)
					default: throw invalid(source, "局所修飾子が不正です。")
				}
			}
			values.append(flags)
		}
		guard !used.isEmpty else {
			throw invalid(source, "局所修飾子が空です。")
		}
		return .init(add: values[0], remove: values.count == 2 ? values[1] : [])
	}

}
