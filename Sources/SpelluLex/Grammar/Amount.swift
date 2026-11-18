import Basis


///
/// 数量の範囲
///
public enum Amount : Hashable, Sendable {
	
	case zeroOrMore        // *
	case oneOrMore         // +
	case zeroOrOne         // ?
	case exactly(Int)      // {n}
	case nOrMore(Int)      // {n,}
	case upToN(Int)        // {,n}
	case range(Int, Int)   // {n,m}
	
}


extension Amount {

	/// 数量範囲の最小値
	public var min: Int {
		switch self {
			case .zeroOrMore:
				0
			case .oneOrMore:
				1
			case .zeroOrOne:
				0
			case .exactly(let n):
				n
			case .nOrMore(let n):
				n
			case .upToN:
				0
			case .range(let n, _):
				n
		}
	}

	/// 数量範囲の最大値 or nil(== "infinity")
	public var max: Int? {
		switch self {
			case .zeroOrMore:
				nil
			case .oneOrMore:
				nil
			case .zeroOrOne:
				1
			case .exactly(let n):
				n
			case .nOrMore:
				nil
			case .upToN(let n):
				n
			case .range(_, let m):
				m
		}
	}
	
	///
	/// 1減らす
	///
	public var decrement: Self {
		switch self {
			case .zeroOrMore:
				.zeroOrMore
			case .oneOrMore:
				.zeroOrMore
			case .zeroOrOne:
				.exactly(0)
			case .exactly(let n):
				.exactly(n - 1)
			case .nOrMore(let n):
				n == 1 ? .zeroOrMore : .nOrMore(n - 1)
			case .upToN(let n):
				.upToN(n - 1)
			case .range(let n, let m):
				.range(n - 1, m - 1)
		}
	}
	
	/// 有限の数量はそのまま、無上限の数量は指定値で範囲にする。
	/// 最小回数が指定値より大きい場合も、逆転した範囲は作らない。
	/// 実行時の処理上限との照合は呼び出し側で行う。
	public func asRange(
		_ limit: Int,
	) -> ClosedRange<Int> {
		min...(max ?? Swift.max(min, limit))
	}

	public var asRangeExpression: any RangeExpression<Int> {
		switch self {
			case .zeroOrMore:
				0...
			case .oneOrMore:
				1...
			case .zeroOrOne:
				0...1
			case .exactly(let n):
				n...n
			case .nOrMore(let n):
				n...
			case .upToN(let n):
				...n
			case .range(let n, let m):
				n...m
		}
	}
	
}


extension RangeExpression where Bound == Int {
	
	@inlinable
	public var asAmount: Amount {
		switch self {
			case let range as Range<Bound>:
				// n..<m
				if range.lowerBound == range.upperBound - 1 {
					.exactly(range.lowerBound)
				}
				else if range.lowerBound == 0 {
					.upToN(range.upperBound - 1)
				}
				else {
					.range(range.lowerBound, range.upperBound - 1)
				}
			case let range as ClosedRange<Bound>:
				// n...m
				if range.lowerBound == range.upperBound {
					.exactly(range.lowerBound)
				}
				else if range.lowerBound == 0 {
					.upToN(range.upperBound)
				}
				else {
					.range(range.lowerBound, range.upperBound)
				}
			case let range as PartialRangeUpTo<Bound>:
				// ..<n
				.upToN(range.upperBound - 1)
			case let range as PartialRangeThrough<Bound>:
				// ...n
				.upToN(range.upperBound)
			case let range as PartialRangeFrom<Bound>:
				// n...
				switch range.lowerBound {
					case 0:
						.zeroOrMore
					case 1:
						.oneOrMore
					default:
						.nOrMore(range.lowerBound)
				}

			default:
				preconditionFailure("Unknown Range-Expression: \(self)")
		}
	}
	
}
