

extension SourceNode {

	/// ツリーに含まれる単独ノード(=.parts.isEmpty)のリスト
	public var flatten: [SourceNode] {
		var result: [SourceNode] = []
		
		func walk(_ node: SourceNode) {
			if node.isEmpty {
				result.append(node)
			}
			else {
				for node in node {
					walk(node)
				}
			}
		}
		
		walk(self)
		
		return result
	}
	
}


