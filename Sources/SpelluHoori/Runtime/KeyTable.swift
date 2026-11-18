/// 整数二つをキーにする開番地ハッシュ表。
/// 項目と呼び出しの同一性の判定で、Dictionaryの費用を避ける。
struct KeyTable {

	struct Key : Equatable {
		let high: UInt64
		let low: UInt64
	}

	private var keys: [Key] = []
	private var values: [Int32] = []
	private var count: Int = 0

	/// 見つかれば既存の値を返す。なければ `value` を登録してnilを返す。
	@inline(__always)
	mutating func insert(
		_ key: Key,
		value: Int32,
	) -> Int32? {
		if (count + 1) * 4 > values.count * 3 {
			grow()
		}

		let mask: Int
		= values.count - 1

		var slot: Int
		= Self.hash(key) & mask

		while values[slot] >= 0 {
			if keys[slot] == key {
				return values[slot]
			}

			slot = (slot + 1) & mask
		}

		keys[slot] = key
		values[slot] = value
		count += 1

		return nil
	}

	func find(
		_ key: Key,
	) -> Int32? {
		guard
			!values.isEmpty
		else { return nil }

		let mask: Int
		= values.count - 1

		var slot: Int
		= Self.hash(key) & mask

		while values[slot] >= 0 {
			if keys[slot] == key {
				return values[slot]
			}

			slot = (slot + 1) & mask
		}

		return nil
	}

	private mutating func grow() {
		let capacity: Int
		= Swift.max(16, values.count * 2)

		let oldKeys: [Key]
		= keys

		let oldValues: [Int32]
		= values

		keys = .init(
			repeating: .init(high: 0, low: 0),
			count: capacity,
		)
		values = .init(repeating: -1, count: capacity)

		let mask: Int
		= capacity - 1

		for index: Int in oldValues.indices where oldValues[index] >= 0 {
			var slot: Int
			= Self.hash(oldKeys[index]) & mask

			while values[slot] >= 0 {
				slot = (slot + 1) & mask
			}

			keys[slot] = oldKeys[index]
			values[slot] = oldValues[index]
		}
	}

	@inline(__always)
	private static func hash(
		_ key: Key,
	) -> Int {
		let mixed: UInt64
		= (key.high &* 0x9E37_79B9_7F4A_7C15)
			^ (key.low &* 0xC2B2_AE3D_27D4_EB4F)

		return Int(truncatingIfNeeded: mixed ^ (mixed >> 29))
	}

}
