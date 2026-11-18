@testable import SpelluSakuya

// 観点：空・単一・連結の走査、IDの端、分割方法によらない共有。
@Suite struct SakuyaIDSequencePoolTests {
	@Test func IDを直接保持して連結の内容と順序を保つ() throws {
		let pool: IDSequencePool = .init(
			.init(maximum: SafetyLimits.default.maxWork)
		)
		let a: Int = try pool.single(0)
		let b: Int = try pool.single(1)
		let c: Int = try pool.single(Int.max)
		let ab: Int = try pool.joined(a, b)
		let abc: Int = try pool.joined(ab, c)
		#expect(try pool.values(0).isEmpty)
		#expect(pool.count(0) == 0)
		#expect(pool.first(0) == nil)
		#expect(pool.last(0) == nil)
		#expect(try pool.single(0) == a)
		#expect(pool.count(a) == 1)
		#expect(pool.first(c) == Int.max)
		#expect(pool.last(a) == 0)
		#expect(try pool.joined(0, a) == a)
		#expect(try pool.joined(a, 0) == a)
		#expect(try pool.joined(a, b) == ab)
		#expect(try pool.joined(a, pool.joined(b, c)) == abc)
		#expect(try pool.values(abc) == [0, 1, Int.max])
	}
}
