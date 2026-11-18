import SpelluSakuya
import SpelluHoori


extension Spellu {

	/// 登録文法を消費せず解析木を返す。onを省略すると最初の公開ルール。
	/// fromは元のSourceに対するUTF-8の絶対位置。
	public func parse(
		_ source: Source,
		from offset: Int? = nil,
		method: MatchMethod = .whole,
		strategy: TreeStrategy = .compact,
		as rule: RuleReference? = nil,
	) throws -> SourceNode {
		try parse(
			source,
			from: offset,
			method: method,
			strategy: strategy,
			as: rule,
		)
		.root
	}

	/// 登録文法を消費せず解析木を返す。onを省略すると最初の公開ルール。
	/// fromは元のSourceに対するUTF-8の絶対位置。
	public func parse(
		_ source: Source,
		from offset: Int? = nil,
		method: MatchMethod = .whole,
		strategy: TreeStrategy = .compact,
		as rule: RuleReference? = nil,
	) throws -> SourceTree {
		let startRule: RuleReference
		= try resolve(rule)

		let start: Int
		= offset ?? source.range.lowerBound

		try checkStart(start, source: source)

		switch backend {
			case let .interpreter(parser):
				return try parser.parse(
					source,
					from: start,
					method: method,
					strategy: strategy,
					as: startRule,
				)

			case let .sakuya(parser):
				return try parser.parse(
					source,
					from: start,
					method: method,
					strategy: strategy,
					as: startRule,
				)

			case let .hoori(parser):
				return try parser.parse(
					source,
					from: start,
					method: method,
					strategy: strategy,
					as: startRule,
				)
		}
	}

	@inlinable
	public func parse(
		_ string: String,
		from offset: Int? = nil,
		method: MatchMethod = .whole,
		strategy: TreeStrategy = .compact,
		as rule: RuleReference? = nil,
	) throws -> SourceNode {
		try parse(
			Source.temporary(string),
			from: offset,
			method: method,
			strategy: strategy,
			as: rule,
		)
	}

	@inlinable
	public func parse(
		_ source: Source,
		from offset: Int? = nil,
		method: MatchMethod = .whole,
		strategy: TreeStrategy = .compact,
		as syntax: Syntax,
	) throws -> SourceNode {
		try self
			.input(
				syntax: syntax,
			)
			.parse(
				source,
				from: offset,
				method: method,
				strategy: strategy,
			)
	}

	@inlinable
	public func parse(
		_ string: String,
		from offset: Int? = nil,
		method: MatchMethod = .whole,
		strategy: TreeStrategy = .compact,
		as syntax: Syntax,
	) throws -> SourceNode {
		try self
			.input(
				syntax: syntax,
			)
			.parse(
				.temporary(string),
				from: offset,
				method: method,
				strategy: strategy,
			)
	}

}


