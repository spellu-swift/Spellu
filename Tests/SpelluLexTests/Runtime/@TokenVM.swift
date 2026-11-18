@testable import SpelluLex


// 対象API: TokenVM.init/stream/maxRepetition/match。
// 部分入力、巻き戻しと再利用、上限の補正、Programの共有を確認する。
// 文法の意味論はTokenMatchingSemanticsTestsでMatcherと同じ条件を使う。
@Suite struct TokenVMTests {

	@Test func 部分入力の開始位置と終端を守る() {
		let source: TokenInputStream = .init("xΣb!", range: 1..<4)
		for optimized: Bool in [false, true] {
			let compiler: TokenProgramCompiler = .init(
				optimizeSimpleRepetitions: optimized,
			)
			var vm: TokenVM = .init(stream: source, maxRepetition: 65_535)
			#expect(vm.stream.offset == 1)
			#expect(vm.match(compiler.compile(.string("Σb!")))
				== .failure(source.input.endIndex))
			#expect(vm.stream.offset == 1)
			#expect(vm.match(compiler.compile([
				.string("σ").ignoresCase(), .string("b"),
			])) == .success(source.input.endIndex))
			#expect(vm.stream.offset == 4)
			#expect(vm.match(compiler.compile(
				.character(.include(.all)),
			)) == .failure(source.input.endIndex))
			#expect(vm.stream.offset == 4)

			let bounded: TokenInputStream = .init("abc", range: 0..<1)
			for ignoresCase: Bool in [false, true] {
				var limited: TokenVM = .init(
					stream: bounded, maxRepetition: 65_535,
				)
				#expect(limited.match(compiler.compile(
					.alternative([.string("ab"), .string("a")]).ignoresCase(ignoresCase),
				)) == .success(bounded.input.endIndex))
				#expect(limited.stream.offset == 1)
			}
		}
	}

	@Test func VMとProgramを再利用し上限を実行ごとに適用する() {
		let compiler: TokenProgramCompiler = .init()
		let program: TokenProgram = compiler.compile(.string("a").repeat(1...))
		for limit: Int in [0, 1, 2, 3] {
			let stream: TokenInputStream = .init(
				"aaa",
			)
			var vm: TokenVM = .init(stream: stream, maxRepetition: limit)
			#expect((vm.match(program).matchedEnd != nil) == (limit > 0))
			#expect(vm.stream.offset == limit)
			#expect(stream.offset == 0)
		}
		var vm: TokenVM = .init(stream: .init("aab"), maxRepetition: 65_535)
		let choice: TokenProgram = compiler.compile(.alternative([.string("a"), .string("aa")]))
		#expect(vm.match(choice).matchedEnd != nil)
		#expect(vm.stream.offset == 1)
		#expect(vm.match(compiler.compile(.string("missing")))
			== .failure(vm.stream.cursor))
		#expect(vm.stream.offset == 1)
		#expect(vm.match(choice).matchedEnd != nil)
		#expect(vm.stream.offset == 2)
		#expect(vm.match(compiler.compile(.string("b"))).matchedEnd != nil)
		#expect(vm.stream.offset == 3)
	}

	@Test(arguments: [false, true])
	func 最遠位置は照合ごとに初期化し成功時は採用した終了位置を返す(
		optimized: Bool,
	) {
		let input: TokenInputStream = .init("abc!")
		let third: String.Index = input.input.index(
			input.cursor, offsetBy: 3,
		)
		let first: String.Index = input.input.index(after: input.cursor)
		let compiler: TokenProgramCompiler = .init(
			optimizeSimpleRepetitions: optimized,
		)
		var vm: TokenVM = .init(stream: input, maxRepetition: 65_535)
		#expect(vm.match(compiler.compile(.string("abcX"))) == .failure(third))
		#expect(vm.match(compiler.compile(.string("x"))) == .failure(input.cursor))
		#expect(vm.match(compiler.compile(.alternative([.string("abcX"), .string("a")])))
			== .success(first))
		#expect(vm.stream.cursor == first)
		#expect(vm.match(compiler.compile(.string("x"))) == .failure(first))
		#expect(vm.stream.cursor == first)
	}

	@Test(arguments: [Int.min, -1, 0, 1, 3, Int.max])
	func 反復上限は入力から独立した評価器の設定として補正する(
		_ limit: Int,
	) {
		let input: TokenInputStream = .init("aaa")
		let normalized: Int = min(max(0, limit), Int.max - 1)
		let pattern: TokenIR = .string("a").repeat(1...)
		let expected: Int? = normalized > 0 ? min(3, normalized) : nil
		for optimized: Bool in [false, true] {
			let compiler: TokenProgramCompiler = .init(
				optimizeSimpleRepetitions: optimized,
			)
			var vm: TokenVM = .init(stream: input, maxRepetition: limit)
			#expect(vm.maxRepetition == normalized)
			#expect(vm.match(compiler.compile(pattern)).matchedEnd.map {
				input.offset(of: $0)
			} == expected)
			var tooMany: TokenVM = .init(stream: input, maxRepetition: limit)
			#expect(tooMany.match(compiler.compile(
				.string("a").repeat(Int.max...Int.max),
			)) == .failure(input.cursor))
		}
		#expect(input.offset == 0)
	}

	@Test func 同じProgramを独立したVMから並行して使用できる() async {
		let program: TokenProgram = TokenProgramCompiler().compile([
			.alternative([.string("aa"), .string("a")]), .string("b"),
		])
		let cases: [(String, Int?)] = [
			("aab", 3), ("ab", 2), ("aa", nil), ("b", nil),
		]
		await withTaskGroup(of: Bool.self) { group in
			for (input, expected) in cases {
				group.addTask {
					var vm: TokenVM = .init(
						stream: .init(input), maxRepetition: 65_535,
					)
					let actual: Int? = vm.match(program).matchedEnd.map {
						vm.stream.offset(of: $0)
					}
					return actual == expected
				}
			}
			for await matched: Bool in group {
				#expect(matched)
			}
		}
	}

	@Test func 空のProgramは反復上限0でも空成功する() {
		for optimized: Bool in [false, true] {
			let compiler: TokenProgramCompiler = .init(
				optimizeSimpleRepetitions: optimized,
			)
			var vm: TokenVM = .init(stream: .init("a"), maxRepetition: 0)
			#expect(vm.match(compiler.compile([])) == .success(vm.stream.cursor))
			#expect(vm.stream.offset == 0)
		}
	}

}


