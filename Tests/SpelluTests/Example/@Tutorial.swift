import SpelluCore


@Grammar(
	spaces: [.space],
)
struct TutorialGrammar_1 {
	
	@Rule
	public let tour = Syntax {
		"to Japan"
	}

}


@Suite
struct Tutorial {
	
	@Test func t_1() throws {
		let source: String
		= "  to Japan"
		
		let tree: SourceNode
		= try source.wholeMatch(
			on: TutorialGrammar_1.default,
			as: \.$tour,
		)
		
		#expect(tree.label == "tour")
		#expect(tree.string == "to Japan")
	}
	
}


@Grammar(
	spaces: [.space],
)
public struct PathGrammar {
	
	public init(
		pathSeparator: String = "/",
	) {
		self.pathSeparator = pathSeparator
	}

	let pathSeparator: String
	
	@Rule
	public var expression: Syntax {
		Syntax {
			List(lastSeparator: .allow) {
				$pathComponent
			} separator: {
				pathSeparator
			}
		}
	}
	
	@Rule
	public let pathComponent = Syntax {
		"..."
	}
	
}


//@Test func usePathGrammar() throws {
//	let unixPath = PathGrammar(pathSeparator: "/")
//	
//	let tree: SourceNode
//	= try ".../...".wholeMatch(
//		engine: .sakuya,
//		on: unixPath,
//	) {
//		PathGrammar.$expression
//	}
//	
//	#expect(tree.string == ".../...")
//}


@Grammar(
	spaces: [.space],
)
struct TutorialGrammar_2 {

	@Rule
	public let element = Syntax {
		$name.as(label: "identifier")
	}

	@Rule
	public let name = Syntax {
		Token {
			Character.word.repeat(1...)
		}
	}
	
}


@Test func tutorial_relabel() throws {
	let source: Source = "aaa"
	
	let tree: SourceNode
	= try source.wholeMatch(
		engine: .interpreter,
		on: TutorialGrammar_2.default,
		as: \.$element,
	)
	
	#expect(tree.first("identifier")?.string == "aaa")
}

