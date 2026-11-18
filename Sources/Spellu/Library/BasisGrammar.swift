

@Grammar(
	spaces: [.space]
)
public struct BasisGrammar {

	@Rule
	public let bom = Syntax {
//		"\u{ef}\u{bb}\u{bf}" // == /\xef\xbb\xbf/
		Fragment("\u{FEFF}")
	}

	@Rule
	public let shebang = Syntax {
		"#!"
		Token(label: "command") {
			Character.notNewline.repeat(0...)
		}
		Optional { Fragment{ Character.newline } }
	}
	
	// TODO: Quoted String
	// TODO: Number
	// TODO: 10進数、16進数、浮動小数点数、NaN
	
}
