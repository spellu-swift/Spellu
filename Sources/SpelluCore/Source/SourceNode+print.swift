import Basis


extension SourceNode : CustomTreeStringConvertible {
	
	///
	/// ツリーを出力する
	///
	public func renderTree() -> [String] {
		var lines: [String] = []
		
		walk(indent: 0, self)
		
		return lines
		
		func walk(
			indent: Int,
			_ node: SourceNode,
		) {
			append(
				indent: indent,
				line: node.lineDescription,
			)

			for part in node {
				walk(indent: indent + 1, part)
			}
		}
		
		func append(
			indent: Int,
			line: String,
		) {
			lines += String(repeating: "\t", count: indent) + line
		}
	}
	
	var lineDescription: String {
		if parts.isEmpty {
			"\(label.string?.wrapped("[", "] ") ?? "")(\(begin):\(end)) \(string)"
		} else {
			"\(label.string?.wrapped("[", "] ") ?? "")(\(begin):\(end))"
		}
	}

}


extension [SourceNode] {
	
	///
	/// ツリーを出力する
	///
	public func dumpTree() {
		for element in self {
			element.dumpTree()
		}
	}
	
}


extension SourceNode {
	
	/// ツリータプル表現
	@inlinable
	public var asTreeTuple: TreeTuple<Label, String> {
		TreeTuple(
			label,
			string,
			children: parts.map(\.label, \.string, children: \.parts),
		)
	}
	
}


///
/// Spelluテスト用のTreeビルダー
///
public func Tree(
	label: String? = nil,
	_ string: String,
) -> TreeTuple<Label, String> {
	TreeTuple(
		Label(label), string,
	)
}


///
/// Spelluテスト用のTreeビルダー
///
public func Tree(
	label: String? = nil,
	_ string: String,
	@TreeTupleBuilder _ children: () -> [TreeTuple<Label, String>] = { [] },
) -> TreeTuple<Label, String> {
	TreeTuple(
		Label(label),
		string,
		children: children(),
	)
}


