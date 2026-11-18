import Basis
import SpelluCore
import SpelluInterpreter
import SpelluSakuya
import SpelluHoori


/// 文法を保持し、生成時に指定したエンジン設定で複数のソースを解析する。
/// 同一インスタンスへの呼び出しは、同じ隔離領域で直列に行う。
public struct Spellu : Sendable {

	let engine: Engine
	let grammars: [SpelluGrammar]
	let backend: Backend

}


extension Spellu {
	
	enum Backend: Sendable {
		case interpreter(SpelluInterpreter.Parser)
		case sakuya(SpelluSakuya.Parser)
		case hoori(SpelluHoori.Parser)
	}

}


extension Spellu {
	
	@inlinable
	public init(
		engine: Engine? = nil,
		on grammar: any GrammarDeclaration,
		_ others: any GrammarDeclaration...,
	) throws {
		try self.init(
			engine: engine,
			on: [grammar] + others,
		)
	}
	
	@inlinable
	public init(
		engine: Engine? = nil,
		on grammars: [any GrammarDeclaration] = [],
	) throws {
		try self.init(
			engine: engine,
			on: grammars.map{ $0.grammar() },
		)
	}

	@inlinable
	public init(
		engine: Engine? = nil,
		on grammar: SpelluGrammar,
		_ others: SpelluGrammar...,
	) throws {
		try self.init(
			engine: engine,
			on: [grammar] + others,
		)
	}

	public init(
		engine: Engine? = nil,
		on grammars: [SpelluGrammar],
	) throws {
		self.engine = engine ?? .interpreter
		self.grammars = grammars

		try Self.check(self.grammars)

		self.backend = try Self.prepare(
			self.grammars,
			for: self.engine,
		)
	}
	
}



extension Spellu {

	static func prepare(
		_ grammars: [SpelluGrammar],
		for engine: Engine,
	) throws -> Backend {
		switch engine {
			case let .interpreter(limits):
				return .interpreter(
					try SpelluInterpreter.Parser(
						grammars: grammars,
						limits: limits,
					),
				)

			case let .sakuya(limits):
				return .sakuya(
					try SpelluSakuya.Parser(
						grammars: grammars,
						limits: limits,
					),
				)

			case let .hoori(limits):
				return .hoori(
					try SpelluHoori.Parser(
						grammars: grammars,
						limits: limits,
					),
				)
		}
	}

}
