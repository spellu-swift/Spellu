

extension SourceNode {
	
//	public func walk(
//		visit: (SourceNode) -> Void
//	) {
//		visit(self)
//		
//		for node in self.parts {
//			node.walk(visit: visit)
//		}
//	}
	
	public func walk(
		visit: (SourceNode) -> Void,
	) {
		struct Context {
			var nodes: [SourceNode]
			var index: Int
			
			@inlinable
			var next: SourceNode? {
				mutating get {
					defer {
						index += 1
					}
					return nodes.get(at: index)
				}
			}
		}
		
		var stack: [Context] = Array(capacity: 64)
		var last: Int = -1
		
		stack.append(
			Context(
				nodes: [self],
				index: 0,
			),
		)
		last += 1
		
		while last >= 0 {
			if
				let node: SourceNode = stack[last].next
			{
				visit(node)
				
				if node.parts.count > 0 {
					stack.append(
						Context(
							nodes: node.parts,
							index: 0,
						),
					)
					last += 1
				}
			}
			else {
				stack.removeLast()
				last -= 1
			}
		}
	}
	
}


extension SourceNode {
	
	public enum WalkBehavior {
		case topDown
		case bottomUp
	}
	
	public func squashed(
		behavior: WalkBehavior,
		label: String,
		visit: (SourceNode) -> SourceNode?,
	) -> SourceNode {
		switch behavior {
			case .topDown:
				squashedTopDown(label: label, visit: visit)
			case .bottomUp:
				squashedBottomUp(label: label, visit: visit)
		}
	}

	private func squashedTopDown(
		label: String,
		visit: (SourceNode) -> SourceNode?,
	) -> SourceNode {
		if
			self.label == .labeled(label),
			let node = visit(self)
		{
			return node
		}
		
		var node = self
		
		node.parts = node.parts.map {
			$0.squashedTopDown(
				label: label,
				visit: visit,
			)
		}
		
		return node
	}
	
	private func squashedBottomUp(
		label: String,
		visit: (SourceNode) -> SourceNode?,
	) -> SourceNode {
		var node = self
		
		node.parts = node.parts.map {
			$0.squashedBottomUp(
				label: label,
				visit: visit,
			)
		}
		
		if self.label == .labeled(label) {
			return visit(node) ?? node
		} else {
			return node
		}
	}
	
}
