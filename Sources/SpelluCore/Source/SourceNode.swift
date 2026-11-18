import Basis


/// ソース内の断片（文字範囲）を表す
public struct SourceNode : Sendable {
	
	public init(
		grammar: String? = .none,
		label: Label = .none,
		source: Source,
		begin: Int,
		end: Int,
		parts: [SourceNode] = []
	) {
		self.grammar = grammar
		self.label = label
		self.source = source
		self.begin = begin
		self.end = end
		self.parts = parts
	}
	
	public var grammar: String?
	public var label: Label
	public var source: Source
	public var begin: Int
	public var end: Int
	public var parts: [SourceNode]
	
}


extension SourceNode : Equatable {}


extension SourceNode {

	@inlinable
	public var range: Range<Int> {
		begin..<end
	}

	@inlinable
	public var position: (Int, Int) {
		source.position(begin)
	}

	@inlinable
	public var string: String {
		substring.asString
	}
	
	@inlinable
	public var substring: Substring {
		source.content[utf8: range]
	}

}


extension Substring.UTF8View {

	@inlinable
	public static func == (
		_ lhs: Self,
		_ rhs: String,
	) -> Bool {
		lhs.elementsEqual(rhs.utf8)
	}
	
	@inlinable
	public static func == (
		_ lhs: Self,
		_ rhs: Substring,
	) -> Bool {
		lhs.elementsEqual(rhs.utf8)
	}
	
}


extension Substring.UTF8View? {

	@inlinable
	public static func == (
		_ lhs: Self,
		_ rhs: String,
	) -> Bool {
		lhs?.elementsEqual(rhs.utf8) ?? false
	}
	
	@inlinable
	public static func == (
		_ lhs: Self,
		_ rhs: Substring,
	) -> Bool {
		lhs?.elementsEqual(rhs.utf8) ?? false
	}
	
}


extension SourceNode : Collection {
	
	public typealias Element = SourceNode
	
	public typealias Index = Int
	
	@inlinable
	public var count: Int {
		parts.count
	}
	
	@inlinable
	public var startIndex: Int {
		0
	}

	@inlinable
	public var endIndex: Int {
		parts.count
	}
	
	@inlinable
	public func index(
		after i: Int,
	) -> Int {
		i + 1
	}
	
	@inlinable
	public subscript(
		position: Int,
	) -> SourceNode {
		parts[position]
	}
	
}


extension SourceNode {

	public func first(
		at index: Int,
	) -> SourceNode? {
		parts.indices ~= index ? parts[index] : nil
	}
	
	public func last(
		at index: Int,
	) -> SourceNode? {
		let index = parts.count - index
		
		return parts.indices ~= index ? parts[index] : nil
	}
	
	@inlinable
	public subscript(
		at offsets: Int...,
	) -> SourceNode? {
		var node: SourceNode? = self

		for offset in offsets {
			node = node?.parts.get(at: offset)
		}
		
		return node
	}
	
	public func contains(
		grammar: String? = .none,
		label: Label,
	) -> Bool {
		[self].query([QueryCommand.label(grammar: grammar, label)]) != nil
	}
	
}


extension SourceNode {
	
	@inlinable
	public var isTemporary: Bool {
		label.isTemporary && parts.allSatisfy{ $0.label == .none }
	}
	
}
	

extension SourceNode {
	
	public func `as`(
		label: Label,
	) -> SourceNode {
		var node = self
		node.label = label
		return node
	}
	
	public var asFragment: SourceFragment {
		SourceFragment(
			source: source,
			begin: begin,
			end: end,
		)
	}
	
}


extension SourceNode : CustomDebugStringConvertible {

	public var debugDescription: String {
		"#\(grammar ?? "").\(label.string ?? "") (\(begin):\(end)) [\(parts.count)]"
	}
	
}
