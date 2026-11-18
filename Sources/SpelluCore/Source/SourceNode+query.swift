
///
/// クエリ機能
///


/// ちゃっぴーのよる指摘(2026.9.28)
///
/// 改善点は主に2つです。
/// - first() / query(..., limit: 1) の limit を、各QueryCommandの途中結果に適用しない方がよい。
///	 途中の最初の候補が後続条件にマッチしない場合、本来見つかるはずの後続候補を探索できなくなる。limit は基本的に最終結果にだけ適用するのが自然。
/// - [SourceNode].search(...) で、複数rootを走査すると limit を超える可能性がある。
///	 各rootの探索前、または SourceNode.search(...) の先頭で result.count >= limit を確認して打ち切ると安全。
///
/// 特に1つ目は correctness に関わるので優先度高め。2つ目は主に効率と上限保証の問題。
///

extension SourceNode {
	
	/// 検索対象
	public enum QueryScope {
		case selves
		case children
		case shallowDescendants
		case deepDescendants
	}
	
	/// 検索コマンド
	public struct QueryCommand {
		public init(
			scope: QueryScope,
			method: QueryMethod,
		) {
			self.scope = scope
			self.method = method
		}
		
		public let scope: QueryScope
		public let method: QueryMethod
	}
	
	/// 検索メソッド
	public enum QueryMethod {
		case all
		case label(_ grammar: String?, _ label: Label) // ラベル、完全一致
		case custom((SourceNode) -> Bool)
	}
	
}


extension SourceNode.QueryCommand {
	
	public static func label(
		grammar: String? = .none,
		_ string: Label,
	) -> Self {
		.init(
			scope: .shallowDescendants,
			method: .label(grammar, string),
		)
	}

	public static func custom(
		_ `where`: @escaping (SourceNode) -> Bool,
	) -> Self {
		.init(
			scope: .shallowDescendants,
			method: .custom(`where`),
		)
	}
	
}


// MARK: セレクタ

struct SourceNodeSelector {
	
	enum ParseError : Swift.Error {
		case parseFailed
	}

	static func parse(
		selector string: String,
	) throws -> [SourceNode.QueryCommand] {
		var result: [SourceNode.QueryCommand] = []
		var offset = 0
		
		while offset < string.count {
			result.append(
				try parse(
					component: string,
					offset: &offset,
				)
			)
		}
		
		return result
	}
	
	static func parse(
		component string: String,
	) throws -> SourceNode.QueryCommand {
		var offset = 0

		return try parse(
			component: string,
			offset: &offset,
		)
	}
	
	/// ex)
	///  "*"
	///  "rule"
	///  "/grammar:rule"
	static func parse(
		component string: String,
		offset: inout Int,
	) throws -> SourceNode.QueryCommand {
		guard
			let match = string[offset...].prefixMatch(of: /\s*(\/>*)?\s*(?:(.+):)?(.+?)(?=\s|\/|$)/)
		else { throw ParseError.parseFailed }
		
		offset += match.0.count

		var method: SourceNode.QueryMethod {
			if match.3 == "*" {
				.all
			}
			else {
				.label(
					match.2?.asString,
					Label(match.3.asString),
				)
			}
		}
		
		switch match.1 {
			case "/":
				return .init(
					scope: .children,
					method: method
				)
				
			case "/>":
				return .init(
					scope: .shallowDescendants,
					method: method
				)
				
			case "/>>":
				return .init(
					scope: .deepDescendants,
					method: method
				)
				
			case nil:
				return .init(
					scope: .shallowDescendants,
					method: method
				)
				
			default:
				throw ParseError.parseFailed
		}
	}
	
}


// MARK: クエリ
// "label" == "/>label"
// "/label" 子要素のみを探索
// "/>label" 子孫要素（浅く）のみを探索
// "/>>label" 子孫要素（深く）のみを探索

extension SourceNode {
	
	// 検索
	@inlinable
	public func first(
		_ selector: String,
	) -> SourceNode? {
		query(
			selector: selector,
		)
	}
	
	// 検索
	@inlinable
	public func all(
		_ selector: String,
	) -> [SourceNode] {
		queryAll(
			selector: selector,
		)
	}
	
	/// ツリーを探索し、最初にマッチしたフラグメントの文字列表現を返す
	@inlinable
	public func query(
		selector: String,
	) -> SourceNode? {
		queryAll(
			selector: selector,
			limit: 1,
		).first
	}
	
	/// ツリーを探索し、マッチした全てのフラグメントの文字列表現を返す
	public func queryAll(
		selector: String,
		limit: Int = .max,
	) -> [SourceNode] {
		(
			try? [self].queryAll(
				SourceNodeSelector.parse(selector: selector),
				limit: limit,
			)
		) ?? []
	}
	
	func search(
		result: inout [SourceNode],
		for scope: QueryScope,
		limit: Int,
		candidate: (SourceNode) -> Bool,
	) {
		switch scope {
			case .selves:
				if candidate(self) {
					result.append(self)
				}
				
			case .children:
				for el in parts {
					if candidate(el) {
						result.append(el)
						
						if result.count >= limit {
							break
						}
					}
				}
				
			case .shallowDescendants:
				for el in parts {
					if candidate(el) {
						result.append(el)

						if result.count >= limit {
							break
						}
					} else {
						el.search(
							result: &result,
							for: scope,
							limit: limit,
							candidate: candidate,
						)
					}
				}

			case .deepDescendants:
				for el in parts {
					if candidate(el) {
						result.append(el)

						if result.count >= limit {
							break
						}
					}
					
					el.search(
						result: &result,
						for: scope,
						limit: limit,
						candidate: candidate,
					)
				}
		}
	}
	
}


extension [SourceNode] {
	
	// 検索
	@inlinable
	public func first(
		_ selector: String,
	) -> SourceNode? {
		query(
			selector: selector,
		)
	}
	
	// 検索
	@inlinable
	public func all(
		_ selector: String,
	) -> [SourceNode] {
		queryAll(
			selector: selector,
		)
	}
	
	/// ツリーを探索し、最初にマッチしたフラグメントの文字列表現を返す
	@inlinable
	public func query(
		selector: String,
	) -> SourceNode? {
		queryAll(
			selector: selector,
			limit: 1,
		).first
	}
	
	/// ツリーを探索し、マッチした全てのフラグメントの文字列表現を返す
	public func queryAll(
		selector: String,
		limit: Int = .max,
	) -> [SourceNode] {
		(
			try? queryAll(
				SourceNodeSelector.parse(selector: selector),
				limit: limit,
			)
		) ?? []
	}
	
	func query(
		_ commands: [SourceNode.QueryCommand],
	) -> SourceNode? {
		queryAll(commands, limit: 1).first
	}
	
	
	/// ツリーを探索し、マッチした全てのフラグメントの文字列表現を返す
	func queryAll(
		_ commands: [SourceNode.QueryCommand],
		limit: Int = .max,
	) -> [SourceNode] {
		guard limit > 0 else { return [] }

		var result: [SourceNode] = self
		
		for (index, command) in commands.enumerated() {
			let searchLimit = index == commands.count - 1 ? limit : Int.max
			switch command.method {
				case .all:
					result = result.search(
						for: command.scope,
						limit: searchLimit,
					) { _ in true }
					
				case .label(let grammar, let label):
					result = result.search(
						for: command.scope,
						limit: searchLimit,
					) {
						// 1. grammarが指定されていれば、grammarをテスト
						if
							let grammar,
							$0.grammar != grammar
						{ return false }
						
						// 2. labelをテスト
						return $0.label == label
					}
					
				case .custom(let candidate):
					result = result.search(
						for: command.scope,
						limit: searchLimit,
						candidate: candidate,
					)
			}
		}
		
		return Array(result.prefix(limit))
	}
	
	func search(
		for scope: SourceNode.QueryScope,
		limit: Int,
		candidate: (Element) -> Bool,
	) -> [Element] {
		var result: [Element] = []
		
		for el in self {
			el.search(
				result: &result,
				for: scope,
				limit: limit,
				candidate: candidate,
			)
		}
		
		return result
	}
	
}


