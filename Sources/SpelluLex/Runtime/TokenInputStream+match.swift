

extension TokenInputStream {
	
	/// 成功時は終了位置、失敗時は全試行の最遠位置を返す。入力は進めない。
	public func match(
		_ pattern: TokenIR,
		engine: TokenEngine,
		maxTokenRepetition: Int = 1024 * 16,
	) -> TokenMatchResult {
		switch engine {
			case .interpreter:
				var matcher: TokenMatcher
				= .init(stream: self, maxRepetition: maxTokenRepetition)
				
				return matcher.match(pattern)

			case .momojiri:
				let program: TokenProgram
				= TokenProgramCompiler(
					optimizeSimpleRepetitions: true,
				).compile(pattern)

				var vm: TokenVM
				= .init(stream: self, maxRepetition: maxTokenRepetition)

				return vm.match(program)
		}
	}
	
	/// 成功時は終了位置、失敗時は全試行の最遠位置を返す。入力は進めない。
	public func match(
		_ pattern: TokenProgram,
		maxTokenRepetition: Int = 1024 * 16,
	) -> TokenMatchResult {
		var vm: TokenVM
		= .init(stream: self, maxRepetition: maxTokenRepetition)

		return vm.match(pattern)
	}
	
}


