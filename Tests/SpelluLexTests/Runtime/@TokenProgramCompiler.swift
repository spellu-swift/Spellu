@testable import SpelluLex


// 対象API・観点:
// Compiler.init/compile: 単体・配列、設定、再利用。
// Program: 定数の保持、分岐とループの有効な参照先、反復回数によらないコード量。
// 深い入れ子と生成パターンの相互比較はTokenDurabilityTestsで行う。
@Suite struct TokenProgramCompilerTests {

	@Test func 文字列をScalar命令へ分解しない() {
		let compiler: TokenProgramCompiler = .init()
		#expect(compiler.optimizeSimpleRepetitions)
		let program: TokenProgram = compiler.compile(.string("日本語abc"))
		#expect(program.code == [.requireLimit(1), .matchLiteral(0), .accept])
		#expect(program.predicates.isEmpty)
		#expect(program.atoms.isEmpty)
		#expect(program.repetitions.isEmpty)
		#expect(program.loops.isEmpty)
		#expect(program.literals.count == 1)
		if case let .exact(string, bytes) = program.literals[0] {
			#expect(string == "日本語abc")
			#expect(bytes == 12)
		}
		else { Issue.record("文字列の一括比較が必要です") }
	}

	@Test func 大小文字設定を継承し子で上書きできる() {
		let program: TokenProgram = TokenProgramCompiler().compile(
			.sequence([
				.string("Σ").ignoresCase(),
				.string("B").ignoresCase(false),
				.character(.include(.any("a"))),
			]).ignoresCase(),
		)
		if case let .folded(scalars) = program.literals[0] {
			#expect(scalars == [0x03C3])
		}
		else { Issue.record("fold済みScalarが必要です") }
		if case let .exact(string, _) = program.literals[1] {
			#expect(string == "B")
		}
		else { Issue.record("子のfalseを優先します") }
		#expect(program.predicates.count == 1)
		#expect(program.predicates[0].caseInsensitive)
		let scalar: UnicodeScalar = "A"
		#expect(program.predicates[0].set.matches(scalar, caseInsensitive: true))
	}

	@Test func 分岐とループの参照先を解決する() {
		let compiler: TokenProgramCompiler = .init(
			optimizeSimpleRepetitions: false,
		)
		#expect(!compiler.optimizeSimpleRepetitions)
		let program: TokenProgram = compiler.compile([
			.alternative([
				.sequence([.string("a"), .string("b")]).repeat(0...2),
				.string("c"),
				.string("d"),
			]),
			.string("!"),
		])
		let addresses: Range<Int> = program.code.indices
		for instruction: TokenInstruction in program.code {
			switch instruction {
				case let .split(first, retry):
					#expect(addresses.contains(first))
					#expect(addresses.contains(retry))
				case let .jump(target):
					#expect(addresses.contains(target))
				default: break
			}
		}
		#expect(program.loops.count == 1)
		let loop: TokenProgram.Loop = program.loops[0]
		#expect(program.code[loop.decide] == .repeatDecide(0))
		#expect(program.code[loop.body] == .repeatBody(0))
		#expect(program.code[loop.leave] == .repeatLeave(0))
		let repetition: TokenProgram.Repetition
		= program.repetitions[loop.repetition]
		#expect(repetition.minimum == 0)
		#expect(repetition.maximum == 2)
		#expect(repetition.behavior == .eager)
	}

	@Test func 単純反復だけを専用命令にする() {
		let compiler: TokenProgramCompiler = .init()
		let program: TokenProgram = compiler.compile([
			.string("ab", amount: .oneOrMore),
			.character(.include(.any("a")), amount: .zeroOrMore),
			.alternative([.string("x"), .string("y")], amount: .zeroOrMore),
		])
		#expect(program.atoms.count == 2)
		#expect(program.code.contains(.repeatAtom(atom: 0, repetition: 0)))
		#expect(program.code.contains(.repeatAtom(atom: 1, repetition: 1)))
		#expect(program.loops.count == 1)
		#expect(program.repetitions[0].maximum == nil)
		#expect(program.repetitions[1].minimum == 0)
		if case .literal = program.atoms[0] {} else {
			Issue.record("文字列Atomが必要です")
		}
		if case .character = program.atoms[1] {} else {
			Issue.record("文字クラスAtomが必要です")
		}
	}

	@Test(arguments: [false, true])
	func 大きい反復回数でもコードを複製しない(
		_ optimized: Bool,
	) {
		let compiler: TokenProgramCompiler = .init(
			optimizeSimpleRepetitions: optimized,
		)
		let small: TokenProgram = compiler.compile(.string("ab").repeat(2...3))
		let large: TokenProgram = compiler.compile(.string("ab").repeat(20_000...30_000))
		#expect(small.code.count == large.code.count)
		#expect(small.literals.count == large.literals.count)
		#expect(large.repetitions[0].minimum == 20_000)
		#expect(large.repetitions[0].maximum == 30_000)
	}

	@Test func Compilerを再利用しても前の定数を残さない() {
		let compiler: TokenProgramCompiler = .init()
		_ = compiler.compile(.string("old"))
		let empty: TokenProgram = compiler.compile([])
		#expect(empty.code == [.accept])
		#expect(empty.literals.isEmpty)
		let next: TokenProgram = compiler.compile(.string("new"))
		#expect(next.code == [.requireLimit(1), .matchLiteral(0), .accept])
		#expect(next.literals.count == 1)
	}

}
