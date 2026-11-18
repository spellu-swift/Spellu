import SpelluCore


// MARK: 自動Trivia

extension Evaluation {

	/// 自動Triviaの中の位置を進める。
	///
	/// 読むのは「字句Trivia、（構文Trivia、字句Trivia）の繰り返し」。
	/// - 字句Triviaの位置：空白などを読めるだけ読み、構文Triviaの位置へ進む。
	/// - 構文Triviaの位置：ここで終えられる。また、構文Triviaをそれぞれ呼ぶ。
	///   空でなく戻ったものだけ、次の字句Triviaの位置へ進む（`continuation`）。
	///
	/// 失敗を記録するかは呼び出しのモードに従う。命令の前の自動Triviaは記録しない。
	mutating func executeTrivia(
		_ step: TriviaStep,
		of grammar: GrammarID,
		_ descriptor: Descriptor,
		_ session: inout Session,
	) throws {
		switch step {
			case .lexical:
				let end: Int
				= try session.scanLexicalTrivia(
					of: grammar,
					at: descriptor.position,
					silent: descriptor.call.mode.silent,
				)

				try advance(
					descriptor,
					into: .trivia(grammar, .syntax),
					at: end,
					environment: descriptor.environment,
					child: .nothing,
					&session,
				)

			case .syntax:
				try complete(descriptor, &session)

				for index: Int in session.table[grammar].syntaxTrivia.indices {
					try call(
						.syntaxTrivia(grammar, index: index),
						from: descriptor,
						mode: descriptor.call.mode,
						&session,
					)
				}
		}
	}

}
