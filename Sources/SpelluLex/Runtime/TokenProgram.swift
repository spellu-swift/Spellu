import Basis


/// 入力と実行状態を持たず、複数のVMで再利用できる字句プログラム。
public struct TokenProgram : Sendable {

	let code: [TokenInstruction]
	let predicates: [Predicate]
	let literals: [Literal]
	let atoms: [Atom]
	let repetitions: [Repetition]
	let loops: [Loop]

}


extension TokenProgram {

	struct Predicate : Sendable {
		let set: CharacterSet
		let caseInsensitive: Bool
	}

	enum Literal : Sendable {
		case exact(String, byteCount: Int)
		case folded([UInt32])
	}

	enum Atom : Sendable {
		case character(Int)
		case literal(Int)
	}

	struct Repetition : Sendable {
		let minimum: Int
		let maximum: Int?
		let behavior: TokenRepetitionBehavior
	}

	struct Loop : Sendable {
		let repetition: Int
		let decide: Int
		let body: Int
		let leave: Int
	}

}


/// 大きい定数を命令内に保持せず、プールの番号で参照する。
enum TokenInstruction : Equatable, Sendable {

	case matchClass(Int)
	case matchLiteral(Int)
	case split(first: Int, retry: Int)
	case jump(Int)
	case requireLimit(Int)

	case repeatEnter(Int)
	case repeatDecide(Int)
	case repeatBody(Int)
	case repeatNext(Int)
	case repeatLeave(Int)
	case repeatAtom(atom: Int, repetition: Int)

	case atomicEnter
	case atomicLeave
	case fail
	case accept

}
