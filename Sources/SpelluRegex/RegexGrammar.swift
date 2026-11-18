import SpelluCore


/// uモードの正規表現文法。解析にはInterpreter v2を使用する。
/// プロパティ名・escape値・範囲等の静的制約はAST構築で検証する。
@available(macOS 15, iOS 18, *)
@Grammar(spaces: [])
public struct RegexGrammar {

	private static let hex: CharacterClass = .include(
		.range("0"..."9"), .range("a"..."f"), .range("A"..."F"),
	)

	@Rule
	public var expression: Syntax {
		Syntax {
			$alternative
			Repeat { "|"; $alternative }
		}
	}

	@Rule
	var alternative: Syntax {
		Syntax { Repeat { $term } }
	}

	@Rule
	var term: Syntax {
		Syntax {
			ChoiceOf {
				Fragment(label: "assertion") { CharacterClass.any("^$") }
				Fragment(label: "boundary") { ChoiceOf { "\\b"; "\\B" } }
				$lookahead
				Sequence { $atom; Optional { $quantifier } }
			}
		}
	}

	@Rule
	var atom: Syntax {
		Syntax {
			ChoiceOf {
				$nonCapture
				$extensionGroup
				$namedCapture
				$modifiedGroup
				$capture
				$characterClass
				Fragment(label: "dot", ".")
				$reference
				$escape
				Fragment(label: "literal") {
					CharacterClass.any("^$\\.*+?()[]{}|").inverted
				}
			}
		}
	}

	@Rule
	var capture: Syntax {
		Syntax { "("; $expression; ")" }
	}

	@Rule
	var nonCapture: Syntax {
		Syntax { "(?:"; $expression; ")" }
	}

	@Rule
	var namedCapture: Syntax {
		Syntax {
			"(?<"
			Fragment(label: "captureName") {
				CharacterClass.any(">").inverted.repeat(1...)
			}
			">"; $expression; ")"
		}
	}

	@Rule
	var lookahead: Syntax {
		Syntax {
			Fragment(label: "lookaheadPrefix") { ChoiceOf { "(?="; "(?!" } }
			$expression; ")"
		}
	}

	@Rule
	var modifiedGroup: Syntax {
		Syntax {
			"(?"
			Fragment(label: "modifierFlags") {
				CharacterClass.any("ims-").repeat(1...)
			}
			":"; $expression; ")"
		}
	}

	@Rule
	var reference: Syntax {
		Syntax {
			Fragment {
				"\\"
				ChoiceOf {
					Sequence {
						CharacterClass.range("1"..."9"); ASCII.digit.repeat(0...)
					}
					Sequence {
						"k<"; CharacterClass.any(">").inverted.repeat(1...); ">"
					}
				}
			}
		}
	}

	/// lookbehindは引き続き未対応として識別する。
	@Rule
	var extensionGroup: Syntax {
		Syntax {
			Fragment { ChoiceOf { "(?<="; "(?<!" } }
			$expression; ")"
		}
	}

	@Rule
	var quantifier: Syntax {
		Syntax {
			Fragment {
				ChoiceOf {
					CharacterClass.any("*+?")
					Sequence {
						"{"; ASCII.digit.repeat(1...)
						Optional { ","; ASCII.digit.repeat(0...) }
						"}"
					}
				}
				Optional { "?" }
			}
		}
	}

	@Rule
	var characterClass: Syntax {
		Syntax {
			"["; Optional { "^" }
			Repeat { $classItem }
			"]"
		}
	}

	@Rule
	var classItem: Syntax {
		Syntax {
			$classAtom
			Optional { "-"; $classAtom }
		}
	}

	@Rule
	var classAtom: Syntax {
		Syntax {
			ChoiceOf {
				$escape
				Fragment(label: "classLiteral") {
					CharacterClass.any("\\]").inverted
				}
			}
		}
	}

	@Rule
	var escape: Syntax {
		Syntax {
			Fragment {
				"\\"
				ChoiceOf {
					// uモードで一つのScalarを表すサロゲート対。
					Sequence {
						"u"; CharacterClass.any("dD")
						CharacterClass.any("89aAbB"); Self.hex.repeat(2...2)
						"\\u"; CharacterClass.any("dD")
						CharacterClass.any("cCdDeEfF")
						Self.hex.repeat(2...2)
					}
					Sequence { "u{"; Self.hex.repeat(1...); "}" }
					Sequence { "u"; Self.hex.repeat(4...4) }
					Sequence { "x"; Self.hex.repeat(2...2) }
					Sequence {
						"c"
						CharacterClass.include(
							.range("a"..."z"), .range("A"..."Z"),
						)
					}
					Sequence {
						CharacterClass.any("pP"); "{"
						CharacterClass.any("}").inverted.repeat(1...); "}"
					}
					CharacterClass.all
				}
			}
		}
	}

}
