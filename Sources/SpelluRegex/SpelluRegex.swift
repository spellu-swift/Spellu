import Basis
import Spellu


/// uモードの構文をScalar単位で評価する、不変の正規表現。
@available(macOS 15, iOS 18, *)
public struct SpelluRegex : Sendable {

	public let pattern: String
	public let options: Options
	let program: RegexProgram

	public init(
		_ pattern: String,
		options: Options = .init(),
	) throws {
		try options.limits.validate()

		try RegexASTBuilder.checkInput(pattern, limits: options.limits)

		let spellu: Spellu
		= try .init(
			engine: .interpreter(
				limits: .init(),
			),
		)
		.input(RegexGrammar.default)
			
//			limits: .init(
//				maxSyntaxRepetition: options.limits.maximumNodes,
//				maxTokenRepetition: options.limits.maximumPatternScalars,
//			),
		
		let tree: SourceNode
		do {
			tree = try spellu.parse(
				.temporary(pattern),
				method: .whole,
				strategy: .asis,
				as: RegexGrammar.$expression,
			)
		} catch let error as SpelluError {
			switch error {
				case let .unexpected(_, offset, _, _, _):
					throw SpelluRegexError.invalidPattern(
						range: offset..<offset,
						message: "正規表現の構文が不正です。",
					)
				case .safetyStop:
					throw SpelluRegexError.resourceLimit("文法解析")
				default: throw error
			}
		}
		var builder: RegexASTBuilder = .init(options: options)
		let ast: RegexAST = try builder.build(tree)
		self.pattern = pattern
		self.options = options
		self.program = try RegexProgram(ast, limits: options.limits)
	}

	/// 入力範囲全体に一致する候補を、後戻りも含めて探す。
	public func wholeMatch<S : StringProtocol>(
		in input: S,
	) throws -> Match? {
		try evaluate(input, method: .whole)
	}

	/// 入力範囲の先頭から一致する。
	public func prefixMatch<S : StringProtocol>(
		in input: S,
	) throws -> Match? {
		try evaluate(input, method: .prefix)
	}

	/// 左からScalar境界ごとに探索し、最初の一致を返す。
	public func firstMatch<S : StringProtocol>(
		in input: S,
	) throws -> Match? {
		try evaluate(input, method: .search)
	}

	private func evaluate<S : StringProtocol>(
		_ input: S,
		method: RegexVM.Method,
	) throws -> Match? {
		var vm: RegexVM = try .init(
			input: Substring(input), options: options,
		)
		return try vm.match(program, method: method)
	}

}


@available(macOS 15, iOS 18, *)
public struct Options : Sendable {

	public let characterSemantics: CharacterSemantics
	public let ignoresCase: Bool
	public let multiline: Bool
	public let dotMatchesNewlines: Bool
	public let limits: RegexLimits

	public init(
		characterSemantics: CharacterSemantics = .spellu,
		ignoresCase: Bool = false,
		multiline: Bool = false,
		dotMatchesNewlines: Bool = false,
		limits: RegexLimits = .init(),
	) {
		self.characterSemantics = characterSemantics
		self.ignoresCase = ignoresCase
		self.multiline = multiline
		self.dotMatchesNewlines = dotMatchesNewlines
		self.limits = limits
	}

}


/// 構文を変えず、短縮文字クラスとプロパティ名の解釈を選ぶ。
@available(macOS 15, iOS 18, *)
public enum CharacterSemantics : Sendable {

	case spellu
	case ecmaScript2026

}


@available(macOS 15, iOS 18, *)
public struct Match : Sendable {

	/// 範囲の基準となる元の入力。Substringの境界を維持する。
	public let input: Substring
	public let range: Range<String.Index>
	/// 捕捉番号1から順に格納する。未参加はnil、空捕捉は空範囲。
	public let captures: [Range<String.Index>?]
	let namedCaptures: [RegexNamedCapture]

	/// 復号後の名前を、初出の順序で返す。同名の別Alternativeはまとめる。
	public var captureNames: [String] { namedCaptures.map { $0.name.string } }

	/// 名前は符号列で比較する。未参加または存在しない名前はnil。
	public func range(ofCapture name: String) -> Range<String.Index>? {
		let scalars: [UInt32] = name.unicodeScalars.map(\.value)
		guard let group: RegexNamedCapture = namedCaptures.first(where: {
			$0.name.scalars == scalars
		}) else { return nil }
		return group.captures.lazy.compactMap { captures[$0] }.first
	}

	public func capture(named name: String) -> Substring? {
		range(ofCapture: name).map { input[$0] }
	}

	public var substring: Substring { input[range] }

}


@available(macOS 15, iOS 18, *)
public enum SpelluRegexError : ProgramError, Sendable {

	/// rangeはpattern内のUTF-8オフセット。
	case invalidPattern(range: Range<Int>, message: String)
	case unsupportedFeature(range: Range<Int>, feature: String)
	case invalidLimits
	case resourceLimit(String)

}
