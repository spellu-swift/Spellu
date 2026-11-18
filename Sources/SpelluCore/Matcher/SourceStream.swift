import Basis
import SpelluLex


extension SourceStream : ExpressibleByStringLiteral {
	
	public init(
		stringLiteral value: String,
	) {
		self.init(
			.temporary(value),
		)
	}
	
}


public struct SourceStream : Sendable {
	
	public init(
		_ source: Source,
		engine: TokenEngine = .momojiri,
		maxTokenRepetition: Int? = nil,
	) {
		self.source = source
		self.input = source.content
		self.end = source.range.upperBound
		self.engine = engine
		self.maxTokenRepetition = min(max(0, maxTokenRepetition ?? SafetyLimits.DEFAULT_MAX_TOKEN_REPETITION), Int.max - 1)
		self.cursor = source.content.utf8Index(source.range.lowerBound)
	}
	
	public let source: Source
	public let input: String
	public let end: Int
	public let engine: TokenEngine
	public let maxTokenRepetition: Int

	public internal(set) var cursor: String.Index

	public var offset: Int {
		@inlinable
		get {
			source.content.utf8Offset(cursor)
		}
		set {
			cursor = source.content.utf8Index(newValue)
		}
	}

	@inlinable
	public var isEnd: Bool {
		offset >= end
	}
	
	@inlinable
	public var current: UnicodeScalar {
		input.unicodeScalars[cursor]
	}
	
	@inlinable
	public var next: UnicodeScalar {
		input.unicodeScalars[input.unicodeScalars.index(after: cursor)]
	}

	public var remain: Substring.UnicodeScalarView {
		input.unicodeScalars[cursor...]
	}
	
	@inlinable
	public func offset(
		of cursor: String.Index
	) -> Int {
		input.utf8Offset(cursor)
	}
	
	@inlinable
	public func count(
		to cursor: String.Index?
	) -> Int? {
		if let cursor {
			input.utf8Offset(cursor) - offset
		}
		else {
			nil
		}
	}
	
	public mutating func scanNext() -> UnicodeScalar? {
		if isEnd { return nil }

		let here = cursor

		cursor = input.unicodeScalars.index(after: cursor)
		
		return input.unicodeScalars[here]
	}

	/// 指定のcountだけUnicode Scalarを読み進める。
	public mutating func skip(
		count: Int,
	) -> Int {
		let start = offset

		guard
			let after = input.unicodeScalars.index(
				cursor,
				offsetBy: count,
				limitedBy: input.unicodeScalars.endIndex,
			)
		else { return 0 }

		cursor = after

		return offset - start
	}
	
	/// パターンに一致した場合スキャンし、ノードを返す。
	public mutating func scan(
		grammar: String?,
		label: Label,
		pattern: TokenIR,
	) -> SourceNode? {
		let position: Int
		= self.offset

		guard
			case let .success(cursor) = match(pattern)
		else { return nil }
		
		self.cursor = cursor

		return SourceNode(
			grammar: grammar,
			label: label,
			source: source,
			begin: position,
			end: offset,
		)
	}

	/// パターンに一致した場合スキャンし、ノードを返す。
	public mutating func scan(
		grammar: String?,
		label: Label,
		pattern: TokenProgram,
	) -> SourceNode? {
		let position: Int
		= self.offset

		guard
			case let .success(cursor) = match(pattern)
		else { return nil }
		
		self.cursor = cursor

		return SourceNode(
			grammar: grammar,
			label: label,
			source: source,
			begin: position,
			end: offset,
		)
	}

	/// パターンに一致した場合スキャンし、ノードを返す。
	/// wordsは、文字列の長い順にソート済みと仮定する。
	public mutating func scan(
		grammar: String?,
		label: Label,
		wholePattern: TokenIR,
		words: [String],
		caseInsensitive: Bool = false,
	) -> SourceNode? {
		// 入力からワードを切り出す
		guard
			let wholeMatch: SourceNode
				= scan(
					grammar: grammar,
					label: label,
					pattern: wholePattern,
				)
		else { return nil }

		// ワード配列を「長い順」にソートする
		let words: [String]
		= words.uniqued().sorted{ l, r in compare(r, l, \.count) }
		
		// ワードに対しマッチを試す
		let matched: String
		= wholeMatch.string

		if caseInsensitive {
			guard
				words.contains(where: {$0.equalsIgnoringCase(matched)} )
			else { return nil }
		}
		else {
			guard
				words.contains(matched)
			else { return nil }
		}

		// 字句の照合で得た原文範囲と消費位置をそのまま使用する。
		return wholeMatch
	}
	
	/// パターンに一致した場合スキャンし、ノードを返す。
	/// wordsは、文字列の長い順にソート済みと仮定する。
	public mutating func scan(
		grammar: String?,
		label: Label,
		wholePattern: TokenProgram,
		words: [String],
		caseInsensitive: Bool = false,
	) -> SourceNode? {
		// 入力からワードを切り出す
		guard
			let wholeMatch: SourceNode
				= scan(
					grammar: grammar,
					label: label,
					pattern: wholePattern,
				)
		else { return nil }

		// ワード配列を「長い順」にソートする
		let words: [String]
		= words.uniqued().sorted{ l, r in compare(r, l, \.count) }
		
		// ワードに対しマッチを試す
		let matched: String
		= wholeMatch.string

		if caseInsensitive {
			guard
				words.contains(where: {$0.equalsIgnoringCase(matched)} )
			else { return nil }
		}
		else {
			guard
				words.contains(matched)
			else { return nil }
		}

		// 字句の照合で得た原文範囲と消費位置をそのまま使用する。
		return wholeMatch
	}
	
	/// パターンに一致した場合スキャンし、ノードを返す。
	public mutating func scan(
		grammar: String?,
		label: Label,
		trivia: [SpacePattern],
	) -> SourceNode? {
		let position: Int = self.offset

		guard
			case let .success(cursor)
				= match(trivia)
		else { return nil }
		
		self.cursor = cursor

		return SourceNode(
			grammar: grammar,
			label: label,
			source: source,
			begin: position,
			end: offset,
		)
	}

	@discardableResult
	public mutating func consume(
		trivia: [SpacePattern],
	) -> Int {
		let here = self.cursor

		guard
			case let .success(cursor) = match(trivia)
		else { return 0 }

		self.cursor = cursor
		
		return input.utf8.distance(from: here, to: cursor)
	}


}


